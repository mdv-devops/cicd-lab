#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ==========================================
# Configuration
# ==========================================

TEAMCITY_VERSION="2025.11.3"
JDBC_VERSION="42.7.10"

TEAMCITY_HOME="/opt/TeamCity"
TEAMCITY_DATA="/var/lib/teamcity"

TEAMCITY_USER="teamcity"

DB_NAME="teamcity"
DB_USER="teamcity"

DB_PASSWORD_FILE="/etc/teamcity/db-password"

JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"

echo "=========================================="
echo " TeamCity + PostgreSQL Installation"
echo "=========================================="


# ==========================================
# 1. System packages
# ==========================================

echo "[1/10] Installing packages..."

apt-get update

apt-get install -y \
    curl \
    wget \
    tar \
    unzip \
    git \
    vim \
    htop \
    jq \
    openssl \
    ca-certificates \
    openjdk-21-jdk \
    postgresql \
    postgresql-contrib


# ==========================================
# 2. TeamCity user
# ==========================================

echo "[2/10] Creating TeamCity user..."

if ! id "${TEAMCITY_USER}" &>/dev/null; then
    useradd \
        --system \
        --create-home \
        --home-dir /home/teamcity \
        --shell /usr/sbin/nologin \
        "${TEAMCITY_USER}"
fi


# ==========================================
# 3. PostgreSQL
# ==========================================

echo "[3/10] Configuring PostgreSQL..."

systemctl enable --now postgresql

mkdir -p /etc/teamcity
chmod 700 /etc/teamcity

if [ ! -f "${DB_PASSWORD_FILE}" ]; then
    openssl rand -hex 32 > "${DB_PASSWORD_FILE}"
    chmod 600 "${DB_PASSWORD_FILE}"
fi

DB_PASSWORD="$(cat "${DB_PASSWORD_FILE}")"

# Create database user if missing
if ! runuser -u postgres -- \
    psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" \
    | grep -qx 1; then

    runuser -u postgres -- \
        createuser "${DB_USER}"
fi

# Configure password
runuser -u postgres -- \
    psql -v ON_ERROR_STOP=1 \
    -v db_user="${DB_USER}" \
    -v db_password="${DB_PASSWORD}" <<'SQL'
ALTER ROLE :"db_user" WITH LOGIN PASSWORD :'db_password';
SQL

# Create database if missing
if ! runuser -u postgres -- \
    psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" \
    | grep -qx 1; then

    runuser -u postgres -- \
        createdb \
        --encoding=UTF8 \
        --owner="${DB_USER}" \
        "${DB_NAME}"
fi

# PostgreSQL listens locally only
PG_CONF="$(find /etc/postgresql -name postgresql.conf | sort -V | tail -1)"

sed -i \
    "s/^[#[:space:]]*listen_addresses[[:space:]]*=.*/listen_addresses = 'localhost'/" \
    "${PG_CONF}"

systemctl restart postgresql


# ==========================================
# 4. Download TeamCity
# ==========================================

echo "[4/10] Installing TeamCity..."

if [ ! -f "${TEAMCITY_HOME}/bin/teamcity-server.sh" ]; then

    cd /tmp

    curl -fL \
        --retry 3 \
        -o TeamCity.tar.gz \
        "https://download.jetbrains.com/teamcity/TeamCity-${TEAMCITY_VERSION}.tar.gz"

    tar -xzf TeamCity.tar.gz -C /opt

    rm -f TeamCity.tar.gz

fi


# ==========================================
# 5. Data Directory
# ==========================================

echo "[5/10] Creating Data Directory..."

mkdir -p \
    "${TEAMCITY_DATA}/config" \
    "${TEAMCITY_DATA}/lib/jdbc"

chown -R \
    "${TEAMCITY_USER}:${TEAMCITY_USER}" \
    "${TEAMCITY_HOME}" \
    "${TEAMCITY_DATA}"


# ==========================================
# 6. PostgreSQL JDBC Driver
# ==========================================

echo "[6/10] Installing PostgreSQL JDBC..."

JDBC_FILE="${TEAMCITY_DATA}/lib/jdbc/postgresql-${JDBC_VERSION}.jar"

if [ ! -f "${JDBC_FILE}" ]; then

    curl -fL \
        --retry 3 \
        -o "${JDBC_FILE}" \
        "https://repo.maven.apache.org/maven2/org/postgresql/postgresql/${JDBC_VERSION}/postgresql-${JDBC_VERSION}.jar"

fi

chown "${TEAMCITY_USER}:${TEAMCITY_USER}" "${JDBC_FILE}"


# ==========================================
# 7. Database connection
# ==========================================

echo "[7/10] Configuring database connection..."

DB_CONFIG="${TEAMCITY_DATA}/config/database.properties"

if [ ! -f "${DB_CONFIG}" ]; then

    cat > "${DB_CONFIG}" <<EOF
connectionUrl=jdbc:postgresql://127.0.0.1:5432/${DB_NAME}
connectionProperties.user=${DB_USER}
connectionProperties.password=${DB_PASSWORD}
EOF

fi

chown "${TEAMCITY_USER}:${TEAMCITY_USER}" "${DB_CONFIG}"
chmod 600 "${DB_CONFIG}"


# ==========================================
# 8. systemd service
# ==========================================

echo "[8/10] Creating systemd service..."

cat > /etc/systemd/system/teamcity.service <<EOF
[Unit]
Description=JetBrains TeamCity Server
After=network-online.target postgresql.service
Wants=network-online.target
Requires=postgresql.service

[Service]
Type=forking

User=${TEAMCITY_USER}
Group=${TEAMCITY_USER}

Environment="JAVA_HOME=${JAVA_HOME}"
Environment="TEAMCITY_DATA_PATH=${TEAMCITY_DATA}"
Environment="TEAMCITY_SERVER_MEM_OPTS=-Xms1g -Xmx3g"

WorkingDirectory=${TEAMCITY_HOME}

ExecStart=${TEAMCITY_HOME}/bin/teamcity-server.sh start
ExecStop=${TEAMCITY_HOME}/bin/teamcity-server.sh stop

Restart=on-failure
RestartSec=15

TimeoutStartSec=300
TimeoutStopSec=120

LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF


# ==========================================
# 9. PostgreSQL connection test
# ==========================================

echo "[9/10] Testing PostgreSQL..."

PGPASSWORD="${DB_PASSWORD}" \
psql \
    -h 127.0.0.1 \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    -c "SELECT current_database(), current_user;"


# ==========================================
# 10. Start TeamCity
# ==========================================

echo "[10/10] Starting TeamCity..."

systemctl daemon-reload
systemctl enable teamcity
systemctl restart teamcity


echo
echo "=========================================="
echo " Installation completed"
echo "=========================================="
echo

systemctl --no-pager status teamcity || true

echo
echo "TeamCity URL:"
echo "http://192.168.56.20:8111"
echo

echo "Database: ${DB_NAME}"
echo "Database user: ${DB_USER}"
echo "Database password: ${DB_PASSWORD_FILE}"
echo