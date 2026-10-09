
#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ============================================================
# Configuration
# ============================================================

SONAR_VERSION="26.9.0.129388"

SONAR_HOME="/opt/sonarqube"
SONAR_USER="sonarqube"
SONAR_GROUP="sonarqube"

SONAR_HOST="192.168.56.21"
SONAR_PORT="9000"
SONAR_SERVER_URL="http://127.0.0.1:${SONAR_PORT}"

DB_NAME="sonarqube"
DB_USER="sonarqube"
DB_PASSWORD_FILE="/etc/sonarqube/db-password"

JAVA_HOME=""

echo
echo "============================================================"
echo " SonarQube Community Build + PostgreSQL"
echo "============================================================"
echo

# ============================================================
# 1. Install system packages
# ============================================================

echo "[1/11] Installing system packages..."

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    wget \
    unzip \
    vim \
    htop \
    jq \
    openssl \
    fontconfig \
    libfreetype6 \
    openjdk-21-jdk \
    postgresql \
    postgresql-contrib

# ============================================================
# 2. Check Java and architecture
# ============================================================

echo "[2/11] Checking Java and architecture..."

ARCH="$(uname -m)"

if [ "${ARCH}" != "aarch64" ]; then
    echo "ERROR: Expected aarch64, got ${ARCH}"
    exit 1
fi

java -version

JAVA_BIN="$(readlink -f "$(command -v java)")"
JAVA_HOME="$(dirname "$(dirname "${JAVA_BIN}")")"

if [ ! -x "${JAVA_HOME}/bin/java" ]; then
    echo "ERROR: Cannot determine JAVA_HOME."
    exit 1
fi

echo "JAVA_HOME: ${JAVA_HOME}"

# ============================================================
# 3. Configure Linux
# ============================================================

echo "[3/11] Configuring Linux limits..."

cat > /etc/sysctl.d/99-sonarqube.conf <<'EOF'
vm.max_map_count=524288
fs.file-max=131072
EOF

sysctl --system

cat > /etc/security/limits.d/99-sonarqube.conf <<EOF
${SONAR_USER} soft nofile 131072
${SONAR_USER} hard nofile 131072
${SONAR_USER} soft nproc 8192
${SONAR_USER} hard nproc 8192
EOF

# ============================================================
# 4. Create SonarQube user
# ============================================================

echo "[4/11] Creating SonarQube user..."

if ! getent group "${SONAR_GROUP}" >/dev/null; then
    groupadd --system "${SONAR_GROUP}"
fi

if ! id "${SONAR_USER}" >/dev/null 2>&1; then
    useradd \
        --system \
        --gid "${SONAR_GROUP}" \
        --home-dir "${SONAR_HOME}" \
        --shell /usr/sbin/nologin \
        "${SONAR_USER}"
fi

# ============================================================
# 5. Configure PostgreSQL
# ============================================================

echo "[5/11] Configuring PostgreSQL..."

systemctl enable --now postgresql

mkdir -p /etc/sonarqube
chown root:root /etc/sonarqube
chmod 700 /etc/sonarqube

# Generate password once

if [ ! -f "${DB_PASSWORD_FILE}" ]; then
    echo "Generating PostgreSQL password..."
    openssl rand -hex 32 > "${DB_PASSWORD_FILE}"
fi

chown root:root "${DB_PASSWORD_FILE}"
chmod 600 "${DB_PASSWORD_FILE}"

DB_PASSWORD="$(cat "${DB_PASSWORD_FILE}")"

# Create PostgreSQL user

if ! runuser -u postgres -- \
    psql -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" \
    | grep -qx 1; then

    runuser -u postgres -- createuser "${DB_USER}"
fi

# Configure password safely

runuser -u postgres -- \
    psql \
    -v ON_ERROR_STOP=1 \
    -v db_user="${DB_USER}" \
    -v db_password="${DB_PASSWORD}" <<'SQL'

ALTER ROLE :"db_user"
WITH LOGIN
PASSWORD :'db_password';

SQL

# Create database

if ! runuser -u postgres -- \
    psql -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" \
    | grep -qx 1; then

    runuser -u postgres -- \
        createdb \
        --encoding=UTF8 \
        --owner="${DB_USER}" \
        "${DB_NAME}"
fi

# Configure localhost-only PostgreSQL

PG_CONF="$(find /etc/postgresql \
    -name postgresql.conf \
    | sort -V \
    | tail -1)"

if [ -z "${PG_CONF}" ]; then
    echo "ERROR: postgresql.conf not found."
    exit 1
fi

sed -i \
    "s/^[#[:space:]]*listen_addresses[[:space:]]*=.*/listen_addresses = 'localhost'/" \
    "${PG_CONF}"

systemctl restart postgresql

# Verify TCP connection

PGPASSWORD="${DB_PASSWORD}" \
psql \
    -h 127.0.0.1 \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    -v ON_ERROR_STOP=1 \
    -c "SELECT current_database(), current_user;"

# ============================================================
# 6. Download and install SonarQube
# ============================================================

echo "[6/11] Installing SonarQube..."

SONAR_JAR="${SONAR_HOME}/lib/sonar-application-${SONAR_VERSION}.jar"

if [ ! -f "${SONAR_JAR}" ]; then

    if [ -e "${SONAR_HOME}" ]; then
        echo "ERROR: ${SONAR_HOME} exists but expected version is missing."
        echo "Refusing to overwrite an existing installation."
        exit 1
    fi

    DOWNLOAD_DIR="$(mktemp -d)"
    trap 'rm -rf "${DOWNLOAD_DIR}"' EXIT

    curl \
        -fL \
        --retry 5 \
        --retry-delay 5 \
        -o "${DOWNLOAD_DIR}/sonarqube.zip" \
        "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip"

    unzip -q \
        "${DOWNLOAD_DIR}/sonarqube.zip" \
        -d /opt

    mv \
        "/opt/sonarqube-${SONAR_VERSION}" \
        "${SONAR_HOME}"

    rm -rf "${DOWNLOAD_DIR}"
    trap - EXIT

else
    echo "SonarQube already installed."
fi

if [ ! -f "${SONAR_JAR}" ]; then
    echo "ERROR: SonarQube application JAR not found."
    exit 1
fi

mkdir -p \
    "${SONAR_HOME}/data" \
    "${SONAR_HOME}/logs" \
    "${SONAR_HOME}/temp" \
    "${SONAR_HOME}/extensions"

chown -R \
    "${SONAR_USER}:${SONAR_GROUP}" \
    "${SONAR_HOME}"

# ============================================================
# 7. Configure SonarQube
# ============================================================

echo "[7/11] Configuring SonarQube..."

SONAR_CONFIG="${SONAR_HOME}/conf/sonar.properties"

# Remove previously managed keys to avoid duplicates
sed -i -E \
    '/^[[:space:]]*# BEGIN CICD-LAB CONFIG$/,/^[[:space:]]*# END CICD-LAB CONFIG$/d' \
    "${SONAR_CONFIG}"

# Remove old active values of managed properties
sed -i -E \
    '/^[[:space:]]*(sonar\.jdbc\.(username|password|url)|sonar\.web\.(host|port|context))[[:space:]]*=/d' \
    "${SONAR_CONFIG}"

cat >> "${SONAR_CONFIG}" <<EOF

# BEGIN CICD-LAB CONFIG
sonar.jdbc.username=${DB_USER}
sonar.jdbc.password=${DB_PASSWORD}
sonar.jdbc.url=jdbc:postgresql://127.0.0.1:5432/${DB_NAME}

sonar.web.host=0.0.0.0
sonar.web.port=${SONAR_PORT}
# END CICD-LAB CONFIG
EOF

chown \
    "${SONAR_USER}:${SONAR_GROUP}" \
    "${SONAR_CONFIG}"

chmod 600 "${SONAR_CONFIG}"

# ============================================================
# 8. Create systemd service
# ============================================================

echo "[8/11] Creating SonarQube systemd service..."

cat > /etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube Community Build
Documentation=https://docs.sonarsource.com/
After=network-online.target postgresql.service
Wants=network-online.target
Requires=postgresql.service

[Service]
Type=simple

User=${SONAR_USER}
Group=${SONAR_GROUP}

Environment="JAVA_HOME=${JAVA_HOME}"
Environment="ES_TMPDIR=${SONAR_HOME}/temp"

WorkingDirectory=${SONAR_HOME}

ExecStart=${JAVA_HOME}/bin/java -jar ${SONAR_JAR}
SuccessExitStatus=143

Restart=on-failure
RestartSec=15

TimeoutStartSec=300
TimeoutStopSec=120

LimitNOFILE=131072
LimitNPROC=8192

UMask=0027

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sonarqube

# ============================================================
# 9. Start SonarQube
# ============================================================

echo "[9/11] Starting SonarQube..."

systemctl restart sonarqube

# ============================================================
# 10. Wait for SonarQube
# ============================================================

echo "[10/11] Waiting for SonarQube..."

SONAR_READY=false

for i in $(seq 1 120); do

    STATUS="$(
        curl \
            -fsS \
            --max-time 5 \
            "${SONAR_SERVER_URL}/api/system/status" \
            2>/dev/null || true
    )"

    STATE="$(
        printf '%s' "${STATUS}" \
        | jq -r '.status // empty' 2>/dev/null \
        || true
    )"

    if [ "${STATE}" = "UP" ]; then
        echo "SonarQube is UP."
        SONAR_READY=true
        break
    fi

    if [ "${STATE}" = "DB_MIGRATION_NEEDED" ]; then
        echo "Database migration required."
        echo "Open ${SONAR_SERVER_URL}/setup"
        break
    fi

    if ! systemctl is-active --quiet sonarqube; then
        echo "ERROR: SonarQube service stopped."
        break
    fi

    echo "Waiting for SonarQube... ${i}/120 (${STATE:-starting})"
    sleep 5

done

if [ "${SONAR_READY}" != "true" ]; then

    echo
    echo "ERROR: SonarQube did not become ready."

    systemctl --no-pager status sonarqube || true

    echo
    echo "Recent systemd logs:"
    journalctl -u sonarqube -n 100 --no-pager || true

    echo
    echo "SonarQube logs:"

    for LOG in sonar.log web.log es.log ce.log; do
        echo "--- ${LOG} ---"
        tail -60 "${SONAR_HOME}/logs/${LOG}" 2>/dev/null || true
    done

    exit 1
fi

# ============================================================
# 11. Final information
# ============================================================

echo
echo "============================================================"
echo " Installation completed"
echo "============================================================"
echo

echo "SonarQube:"
echo "  Version:  ${SONAR_VERSION}"
echo "  URL:      http://${SONAR_HOST}:${SONAR_PORT}"
echo "  Home:     ${SONAR_HOME}"
echo "  User:     ${SONAR_USER}"
echo

echo "PostgreSQL:"
echo "  Host:     127.0.0.1"
echo "  Port:     5432"
echo "  Database: ${DB_NAME}"
echo "  User:     ${DB_USER}"
echo "  Password: ${DB_PASSWORD_FILE}"
echo

echo "Service status:"

systemctl is-active --quiet postgresql \
    && echo "  PostgreSQL: RUNNING" \
    || echo "  PostgreSQL: FAILED"

systemctl is-active --quiet sonarqube \
    && echo "  SonarQube:  RUNNING" \
    || echo "  SonarQube:  FAILED"

echo
echo "Useful commands:"
echo "  sudo systemctl status sonarqube"
echo "  sudo journalctl -u sonarqube -f"
echo "  sudo tail -f ${SONAR_HOME}/logs/sonar.log"
echo "  curl ${SONAR_SERVER_URL}/api/system/status"
echo

echo "============================================================"
