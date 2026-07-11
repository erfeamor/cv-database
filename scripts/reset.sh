#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker compose -f "$ROOT_DIR/docker-compose.yml" down -v
docker compose -f "$ROOT_DIR/docker-compose.yml" up -d
echo "Waiting for MySQL to be healthy..."
until [ "$(docker inspect -f '{{.State.Health.Status}}' cv-database)" = "healthy" ]; do
  sleep 2
done
"$ROOT_DIR/scripts/migrate.sh"
