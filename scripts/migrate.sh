#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker run --rm --network host \
  -v "$ROOT_DIR/sql/migrations:/flyway/sql" \
  -v "$ROOT_DIR/flyway.conf:/flyway/conf/flyway.conf" \
  flyway/flyway:10 migrate
