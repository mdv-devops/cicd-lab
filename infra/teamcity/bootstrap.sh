#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ============================================================
# Configuration
# ============================================================

TEAMCITY_VERSION="2025.11.3"
JDBC_VERSION="42.7.10"

TEAMCITY_HOME="/opt/TeamCity"
TEAMCITY_DATA="/var/lib/teamcity"

TEAMCITY_AGENT_HOME="/opt/teamcity-agent"
TEAMCITY_AGENT_NAME="teamcity-local-agent"

TEAMCITY_USER="teamcity"
TEAMCITY_GROUP="teamcity"

TEAMCITY_SERVER_URL="http://127.0.0.1:8111"

DB_NAME="teamcity"
DB_USER="teamcity"
DB_PASSWORD_FILE="/etc/teamcity/db-password"

SONAR_SCANNER_HOME="/opt/sonarscanner"
SONAR_SCANNER_VERSION="11.3.0"

JAVA_HOME=""


echo
echo "============================================================"
echo " TeamCity Server + PostgreSQL + Build Agent"
echo "============================================================"
echo


# ============================================================
# 1. Install system packages
# ============================================================

echo "[1/15] Installing system packages..."

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    wget \
    tar \
    unzip \
    git \
    vim \
    htop \
    jq \
    openssl \
    openjdk-21-jdk \
    postgresql \
    postgresql-contrib

# ============================================================
# Install .NET SDK 9
# ============================================================

echo
echo "Installing .NET SDK 9..."

apt-get update

apt-get install -y \
    software-properties-common \
    ca-certificates

add-apt-repository -y ppa:dotnet/backports

apt-get update

apt-get install -y dotnet-sdk-9.0

echo
echo ".NET SDK version:"
dotnet --version

echo
echo "Installed SDKs:"
dotnet --list-sdks

# ============================================================
# Install SonarScanner for .NET
# ============================================================

echo
echo "Installing SonarScanner for .NET ${SONAR_SCANNER_VERSION}..."

mkdir -p "${SONAR_SCANNER_HOME}"

# Pin the tool version to keep Vagrant provisioning reproducible.
# Upgrade an older tool if a different version was installed previously.
INSTALLED_SCANNER_VERSION="$(
    dotnet tool list --tool-path "${SONAR_SCANNER_HOME}" \
        | awk '$1 == "dotnet-sonarscanner" {print $2}'
)"

if [ -z "${INSTALLED_SCANNER_VERSION}" ]; then
    dotnet tool install \
        --tool-path "${SONAR_SCANNER_HOME}" \
        --version "${SONAR_SCANNER_VERSION}" \
        dotnet-sonarscanner
elif [ "${INSTALLED_SCANNER_VERSION}" != "${SONAR_SCANNER_VERSION}" ]; then
    echo "Updating SonarScanner ${INSTALLED_SCANNER_VERSION} -> ${SONAR_SCANNER_VERSION}..."
    dotnet tool update \
        --tool-path "${SONAR_SCANNER_HOME}" \
        --version "${SONAR_SCANNER_VERSION}" \
        dotnet-sonarscanner
else
    echo "SonarScanner ${SONAR_SCANNER_VERSION} already installed."
fi

chmod -R a+rX "${SONAR_SCANNER_HOME}"

ln -sfn \
    "${SONAR_SCANNER_HOME}/dotnet-sonarscanner" \
    /usr/local/bin/dotnet-sonarscanner

echo "SonarScanner installed:"
dotnet tool list --tool-path "${SONAR_SCANNER_HOME}"

# ============================================================
# Install ReportGenerator
# ============================================================

REPORTGENERATOR_HOME="/opt/reportgenerator"

echo
echo "Installing ReportGenerator..."

mkdir -p "${REPORTGENERATOR_HOME}"

INSTALLED_REPORTGENERATOR_VERSION="$(
    dotnet tool list --tool-path "${REPORTGENERATOR_HOME}" \
        | awk '$1 == "dotnet-reportgenerator-globaltool" {print $2}'
)"

if [ -z "${INSTALLED_REPORTGENERATOR_VERSION}" ]; then
    dotnet tool install \
        --tool-path "${REPORTGENERATOR_HOME}" \
        dotnet-reportgenerator-globaltool
else
    echo "ReportGenerator ${INSTALLED_REPORTGENERATOR_VERSION} already installed."
fi

chmod -R a+rX "${REPORTGENERATOR_HOME}"

ln -sfn \
    "${REPORTGENERATOR_HOME}/reportgenerator" \
    /usr/local/bin/reportgenerator

echo "ReportGenerator installed:"
dotnet tool list --tool-path "${REPORTGENERATOR_HOME}"

# ============================================================
# 2. Check Java and detect JAVA_HOME
# ============================================================

echo
echo "[2/15] Checking Java..."

java -version

JAVA_BIN="$(readlink -f "$(command -v java)")"
JAVA_HOME="$(dirname "$(dirname "${JAVA_BIN}")")"

echo
echo "Detected Java:"
echo "  java:      ${JAVA_BIN}"
echo "  JAVA_HOME: ${JAVA_HOME}"

if [ ! -x "${JAVA_HOME}/bin/java" ]; then
    echo "ERROR: Cannot determine JAVA_HOME."
    exit 1
fi

echo
echo "Java installation OK."


# ============================================================
# 3. Create TeamCity user
# ============================================================

echo
echo "[3/15] Creating TeamCity user..."

if ! getent group "${TEAMCITY_GROUP}" >/dev/null 2>&1; then
    groupadd --system "${TEAMCITY_GROUP}"
fi

if ! id "${TEAMCITY_USER}" >/dev/null 2>&1; then

    useradd \
        --system \
        --gid "${TEAMCITY_GROUP}" \
        --create-home \
        --home-dir /home/teamcity \
        --shell /usr/sbin/nologin \
        "${TEAMCITY_USER}"

fi


# ============================================================
# Verify SonarScanner as TeamCity user
# ============================================================

echo
echo "Checking SonarScanner as ${TEAMCITY_USER}..."

SCANNER_OUTPUT="$(
    runuser -u "${TEAMCITY_USER}" -- \
        /usr/local/bin/dotnet-sonarscanner --version 2>&1
)" || true

echo "${SCANNER_OUTPUT}"

if ! grep -q "SonarScanner for .NET" <<< "${SCANNER_OUTPUT}"; then
    echo "ERROR: SonarScanner verification failed."
    exit 1
fi

echo "SonarScanner installation OK."

# ============================================================
# 4. Configure PostgreSQL
# ============================================================

echo
echo "[4/15] Configuring PostgreSQL..."

systemctl enable postgresql
systemctl start postgresql

mkdir -p /etc/teamcity

chown root:root /etc/teamcity
chmod 700 /etc/teamcity


# ------------------------------------------------------------
# Generate database password
# ------------------------------------------------------------

if [ ! -f "${DB_PASSWORD_FILE}" ]; then

    echo "Generating PostgreSQL password..."

    openssl rand -hex 32 > "${DB_PASSWORD_FILE}"

    chown root:root "${DB_PASSWORD_FILE}"
    chmod 600 "${DB_PASSWORD_FILE}"

fi

DB_PASSWORD="$(cat "${DB_PASSWORD_FILE}")"


# ------------------------------------------------------------
# Create PostgreSQL user
# ------------------------------------------------------------

echo "Creating PostgreSQL user..."

if ! runuser -u postgres -- \
    psql -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" \
    | grep -qx 1; then

    runuser -u postgres -- \
        createuser "${DB_USER}"

fi


# ------------------------------------------------------------
# Configure PostgreSQL password
# ------------------------------------------------------------

runuser -u postgres -- \
    psql \
    -v ON_ERROR_STOP=1 \
    -v db_user="${DB_USER}" \
    -v db_password="${DB_PASSWORD}" <<'SQL'

ALTER ROLE :"db_user"
WITH LOGIN
PASSWORD :'db_password';

SQL


# ------------------------------------------------------------
# Create TeamCity database
# ------------------------------------------------------------

echo "Creating TeamCity database..."

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


# ------------------------------------------------------------
# PostgreSQL listen address
# ------------------------------------------------------------

PG_CONF="$(find /etc/postgresql \
    -name postgresql.conf \
    | sort -V \
    | tail -1)"

if [ -z "${PG_CONF}" ]; then
    echo "ERROR: postgresql.conf not found."
    exit 1
fi

echo "PostgreSQL config:"
echo "${PG_CONF}"

sed -i \
    "s/^[#[:space:]]*listen_addresses[[:space:]]*=.*/listen_addresses = 'localhost'/" \
    "${PG_CONF}"

systemctl restart postgresql


# ============================================================
# 5. Test PostgreSQL
# ============================================================

echo
echo "[5/15] Testing PostgreSQL connection..."

PGPASSWORD="${DB_PASSWORD}" \
psql \
    -h 127.0.0.1 \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    -v ON_ERROR_STOP=1 \
    -c "SELECT current_database(), current_user;"


# ============================================================
# 6. Download and install TeamCity Server
# ============================================================

echo
echo "[6/15] Installing TeamCity Server..."

if [ ! -f "${TEAMCITY_HOME}/bin/teamcity-server.sh" ]; then

    cd /tmp

    echo "Downloading TeamCity ${TEAMCITY_VERSION}..."

    curl \
        -fL \
        --retry 5 \
        --retry-delay 5 \
        -o TeamCity.tar.gz \
        "https://download.jetbrains.com/teamcity/TeamCity-${TEAMCITY_VERSION}.tar.gz"

    echo "Extracting TeamCity..."

    tar -xzf TeamCity.tar.gz -C /opt

    rm -f TeamCity.tar.gz

else

    echo "TeamCity is already installed."

fi


# ============================================================
# 7. Create TeamCity Data Directory
# ============================================================

echo
echo "[7/15] Creating TeamCity Data Directory..."

mkdir -p \
    "${TEAMCITY_DATA}" \
    "${TEAMCITY_DATA}/config" \
    "${TEAMCITY_DATA}/lib" \
    "${TEAMCITY_DATA}/lib/jdbc"

chown -R \
    "${TEAMCITY_USER}:${TEAMCITY_GROUP}" \
    "${TEAMCITY_HOME}" \
    "${TEAMCITY_DATA}"


# ============================================================
# 8. Install PostgreSQL JDBC driver
# ============================================================

echo
echo "[8/15] Installing PostgreSQL JDBC driver..."

JDBC_FILE="${TEAMCITY_DATA}/lib/jdbc/postgresql-${JDBC_VERSION}.jar"

if [ ! -f "${JDBC_FILE}" ]; then

    curl \
        -fL \
        --retry 5 \
        --retry-delay 5 \
        -o "${JDBC_FILE}" \
        "https://repo.maven.apache.org/maven2/org/postgresql/postgresql/${JDBC_VERSION}/postgresql-${JDBC_VERSION}.jar"

else

    echo "PostgreSQL JDBC driver already installed."

fi

chown \
    "${TEAMCITY_USER}:${TEAMCITY_GROUP}" \
    "${JDBC_FILE}"

chmod 644 "${JDBC_FILE}"


# ============================================================
# 9. Configure TeamCity database
# ============================================================

echo
echo "[9/15] Configuring TeamCity database..."

DB_CONFIG="${TEAMCITY_DATA}/config/database.properties"

if [ ! -f "${DB_CONFIG}" ]; then

    cat > "${DB_CONFIG}" <<EOF
connectionUrl=jdbc:postgresql://127.0.0.1:5432/${DB_NAME}
connectionProperties.user=${DB_USER}
connectionProperties.password=${DB_PASSWORD}
EOF

else

    echo "database.properties already exists."
    echo "Keeping existing configuration."

fi

chown \
    "${TEAMCITY_USER}:${TEAMCITY_GROUP}" \
    "${DB_CONFIG}"

chmod 600 "${DB_CONFIG}"


# ============================================================
# 10. Create TeamCity Server systemd service
# ============================================================

echo
echo "[10/15] Creating TeamCity Server systemd service..."

cat > /etc/systemd/system/teamcity.service <<EOF
[Unit]
Description=JetBrains TeamCity Server
Documentation=https://www.jetbrains.com/teamcity/
After=network-online.target postgresql.service
Wants=network-online.target
Requires=postgresql.service

[Service]

Type=forking

User=${TEAMCITY_USER}
Group=${TEAMCITY_GROUP}

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

systemctl daemon-reload

systemctl enable teamcity


# ============================================================
# 11. Start TeamCity Server
# ============================================================

echo
echo "[11/15] Starting TeamCity Server..."

systemctl restart teamcity


# ============================================================
# 12. Wait for TeamCity Server
# ============================================================

echo
echo "[12/15] Waiting for TeamCity Server..."

TEAMCITY_READY=false

for i in $(seq 1 120); do

    HTTP_CODE="$(
        curl \
            -s \
            -o /dev/null \
            -w "%{http_code}" \
            "${TEAMCITY_SERVER_URL}/" \
            || true
    )"

    case "${HTTP_CODE}" in

        200|301|302|401|403)

            echo
            echo "TeamCity Server is responding."
            echo "HTTP status: ${HTTP_CODE}"

            TEAMCITY_READY=true
            break
            ;;

    esac

    echo "Waiting for TeamCity... ${i}/120"

    sleep 5

done


if [ "${TEAMCITY_READY}" != "true" ]; then

    echo
    echo "ERROR: TeamCity Server did not become available."
    echo

    systemctl --no-pager status teamcity || true

    echo
    echo "Last TeamCity log lines:"
    echo

    tail -100 \
        "${TEAMCITY_HOME}/logs/teamcity-server.log" \
        2>/dev/null || true

    exit 1

fi


# ============================================================
# 13. Install TeamCity Build Agent
# ============================================================

echo
echo "[13/15] Installing TeamCity Build Agent..."

if [ ! -f "${TEAMCITY_AGENT_HOME}/bin/agent.sh" ]; then

    cd /tmp

    echo "Downloading Build Agent from TeamCity Server..."

    curl \
        -fL \
        --retry 10 \
        --retry-delay 5 \
        -o buildAgent.zip \
        "${TEAMCITY_SERVER_URL}/update/buildAgent.zip"

    rm -rf "${TEAMCITY_AGENT_HOME}"

    mkdir -p "${TEAMCITY_AGENT_HOME}"

    unzip -q \
        buildAgent.zip \
        -d "${TEAMCITY_AGENT_HOME}"

    rm -f buildAgent.zip

else

    echo "TeamCity Build Agent is already installed."

fi


# ============================================================
# 14. Configure TeamCity Build Agent
# ============================================================

echo
echo "[14/15] Configuring TeamCity Build Agent..."

mkdir -p \
    "${TEAMCITY_AGENT_HOME}/conf" \
    "${TEAMCITY_AGENT_HOME}/work" \
    "${TEAMCITY_AGENT_HOME}/temp" \
    "${TEAMCITY_AGENT_HOME}/system"

AGENT_CONFIG="${TEAMCITY_AGENT_HOME}/conf/buildAgent.properties"

if [ ! -f "${AGENT_CONFIG}" ]; then

    cat > "${AGENT_CONFIG}" <<EOF
serverUrl=${TEAMCITY_SERVER_URL}

name=${TEAMCITY_AGENT_NAME}

workDir=../work
tempDir=../temp
systemDir=../system
EOF

else

    echo "buildAgent.properties already exists."
    echo "Keeping existing agent configuration."

fi


chown -R \
    "${TEAMCITY_USER}:${TEAMCITY_GROUP}" \
    "${TEAMCITY_AGENT_HOME}"


# ============================================================
# Create Build Agent systemd service
# ============================================================

echo
echo "Creating TeamCity Build Agent systemd service..."

cat > /etc/systemd/system/teamcity-agent.service <<EOF
[Unit]
Description=JetBrains TeamCity Build Agent
Documentation=https://www.jetbrains.com/teamcity/
After=network-online.target teamcity.service
Wants=network-online.target
Requires=teamcity.service

[Service]

Type=forking

User=${TEAMCITY_USER}
Group=${TEAMCITY_GROUP}

Environment="JAVA_HOME=${JAVA_HOME}"

WorkingDirectory=${TEAMCITY_AGENT_HOME}

ExecStart=${TEAMCITY_AGENT_HOME}/bin/agent.sh start
ExecStop=${TEAMCITY_AGENT_HOME}/bin/agent.sh stop

Restart=on-failure
RestartSec=10

TimeoutStartSec=120
TimeoutStopSec=60

LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF


# ============================================================
# 15. Start Build Agent
# ============================================================

echo
echo "[15/15] Starting TeamCity Build Agent..."

systemctl daemon-reload

systemctl enable teamcity-agent

systemctl restart teamcity-agent

# ============================================================
# Final information
# ============================================================

echo
echo "============================================================"
echo " Installation completed"
echo "============================================================"
echo

echo "TeamCity Server:"
echo "  http://192.168.56.20:8111"
echo

echo "Local Server URL:"
echo "  ${TEAMCITY_SERVER_URL}"
echo

echo "TeamCity:"
echo "  Version: ${TEAMCITY_VERSION}"
echo "  Home:    ${TEAMCITY_HOME}"
echo "  Data:    ${TEAMCITY_DATA}"
echo

echo "Build Agent:"
echo "  Name:    ${TEAMCITY_AGENT_NAME}"
echo "  Home:    ${TEAMCITY_AGENT_HOME}"
echo
echo "SonarScanner:"
echo "  Version: ${SONAR_SCANNER_VERSION}"
echo "  Home:    ${SONAR_SCANNER_HOME}"
echo "  Binary:  /usr/local/bin/dotnet-sonarscanner"
echo

echo "PostgreSQL:"
echo "  Host:     127.0.0.1"
echo "  Port:     5432"
echo "  Database: ${DB_NAME}"
echo "  User:     ${DB_USER}"
echo "  Password: ${DB_PASSWORD_FILE}"
echo

echo "Service status:"
echo

systemctl is-active postgresql \
    && echo "  PostgreSQL:     RUNNING" \
    || echo "  PostgreSQL:     FAILED"

systemctl is-active teamcity \
    && echo "  TeamCity:       RUNNING" \
    || echo "  TeamCity:       FAILED"

systemctl is-active teamcity-agent \
    && echo "  TeamCity Agent: RUNNING" \
    || echo "  TeamCity Agent: FAILED"

echo
echo "Useful commands:"
echo
echo "  sudo systemctl status teamcity"
echo "  sudo systemctl status teamcity-agent"
echo "  sudo systemctl status postgresql"
echo
echo "  sudo tail -f ${TEAMCITY_HOME}/logs/teamcity-server.log"
echo "  sudo tail -f ${TEAMCITY_AGENT_HOME}/logs/teamcity-agent.log"
echo
echo "============================================================"