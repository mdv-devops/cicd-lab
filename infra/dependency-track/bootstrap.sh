#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

DTRACK_VERSION="5.2.2"
POSTGRES_VERSION="18-alpine"
TRIVY_VERSION="0.75.0"
DTRACK_IP="192.168.56.22"
INSTALL_DIR="/opt/dependency-track"

echo "=========================================="
echo "Installing OWASP Dependency-Track"
echo "=========================================="

echo "[1/9] Installing system dependencies"

apt-get update
apt-get install -y ca-certificates curl gnupg openssl jq

echo "[2/9] Configuring Docker repository"

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

ARCH=$(dpkg --print-architecture)

. /etc/os-release

echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list

echo "[3/9] Installing Docker Engine"

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

usermod -aG docker vagrant

echo "[4/9] Preparing installation directory"

install -d -m 0750 -o vagrant -g vagrant "${INSTALL_DIR}"

cd "${INSTALL_DIR}"

echo "[5/9] Preparing environment variables"

if [[ ! -f .env ]]; then
    (
        umask 077
        touch .env
    )
fi

if ! grep -q '^POSTGRES_PASSWORD=' .env; then
    echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)" >> .env
fi

if ! grep -q '^TRIVY_TOKEN=' .env; then
    echo "TRIVY_TOKEN=$(openssl rand -hex 32)" >> .env
fi

chown vagrant:vagrant .env
chmod 600 .env

echo "[6/9] Creating Docker Compose configuration"

cat > docker-compose.yml <<EOF
services:
  postgres:
    image: postgres:${POSTGRES_VERSION}
    container_name: dependency-track-postgres
    restart: unless-stopped

    environment:
      POSTGRES_DB: dtrack
      POSTGRES_USER: dtrack
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}

    mem_limit: 512m

    volumes:
      - postgres-data:/var/lib/postgresql

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dtrack -d dtrack"]
      interval: 10s
      timeout: 5s
      retries: 10

  apiserver:
    image: ghcr.io/dependencytrack/apiserver:${DTRACK_VERSION}
    container_name: dependency-track-apiserver
    restart: unless-stopped

    depends_on:
      postgres:
        condition: service_healthy

    environment:
      DT_DATASOURCE_URL: jdbc:postgresql://postgres:5432/dtrack
      DT_DATASOURCE_USERNAME: dtrack
      DT_DATASOURCE_PASSWORD: \${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}
      EXTRA_JAVA_OPTIONS: "-Xms512m -Xmx1536m"

    mem_limit: 2560m

    ports:
      - "${DTRACK_IP}:8081:8080"

    volumes:
      - apiserver-data:/data

  frontend:
    image: ghcr.io/dependencytrack/frontend:${DTRACK_VERSION}
    container_name: dependency-track-frontend
    restart: unless-stopped

    depends_on:
      - apiserver

    environment:
      API_BASE_URL: http://${DTRACK_IP}:8081

    mem_limit: 128m

    ports:
      - "${DTRACK_IP}:8080:8080"

  trivy:
    image: aquasec/trivy:${TRIVY_VERSION}
    container_name: dependency-track-trivy
    restart: unless-stopped

    command:
      - server
      - --listen
      - 0.0.0.0:4954

    environment:
      TRIVY_TOKEN: \${TRIVY_TOKEN:?TRIVY_TOKEN is required}
      TRIVY_CACHE_DIR: /root/.cache/trivy

    mem_limit: 512m

    volumes:
      - trivy-data:/root/.cache/trivy

volumes:
  postgres-data:
  apiserver-data:
  trivy-data:
EOF

chown vagrant:vagrant docker-compose.yml
chmod 640 docker-compose.yml

echo "[7/9] Validating configuration and pulling images"

docker compose config --quiet

docker compose pull

echo "Container image architectures:"

docker image inspect "ghcr.io/dependencytrack/apiserver:${DTRACK_VERSION}" "ghcr.io/dependencytrack/frontend:${DTRACK_VERSION}" "postgres:${POSTGRES_VERSION}" "aquasec/trivy:${TRIVY_VERSION}" --format '{{.RepoTags}} {{.Os}}/{{.Architecture}}'

echo "[8/9] Starting Dependency-Track"

docker compose up -d

echo "[9/9] Checking container status"

docker compose ps

echo "=========================================="
echo "Dependency-Track containers started"
echo "=========================================="
echo "Frontend: http://${DTRACK_IP}:8080"
echo "API:      http://${DTRACK_IP}:8081"
echo "Trivy:    http://trivy:4954 (internal)"
echo "=========================================="
echo "Installation directory: ${INSTALL_DIR}"
echo "Initial startup may take several minutes."
echo "=========================================="
