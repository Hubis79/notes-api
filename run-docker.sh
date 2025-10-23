#!/usr/bin/env bash
set -euo pipefail

# Notes API Docker setup and serve helper (uses repo-root docker-compose.yml)
# Usage: ./run-docker.sh

# Ensure docker is available
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not on PATH." >&2
  exit 1
fi

# Resolve docker compose command (supports plugin and legacy binary)
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "Error: neither 'docker compose' nor 'docker-compose' is available." >&2
  echo "Install Docker Desktop (preferred) or the docker-compose standalone binary/plugin." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="docker-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Error: docker-compose.yml not found in current directory." >&2
  exit 1
fi

# Resolve host DB port (used only for host binding; inside Docker it's always 3306)
DB_HOST_PORT="${DB_HOST_PORT:-3306}"
export DB_HOST_PORT

# If port is already in use, try to free it when it's used by Docker; otherwise, advise and exit
if lsof -iTCP:"$DB_HOST_PORT" -sTCP:LISTEN -n -P >/dev/null 2>&1; then
  # Check if a Docker container publishes this port
  CONFLICTING_IDS=$(docker ps --format '{{.ID}} {{.Ports}}' | awk -v p=":${DB_HOST_PORT}->" 'index($0,p){print $1}') || true
  if [ -n "$CONFLICTING_IDS" ]; then
    echo "Port $DB_HOST_PORT is in use by Docker container(s): $CONFLICTING_IDS. Stopping them..."
    docker stop $CONFLICTING_IDS >/dev/null 2>&1 || true
    docker rm $CONFLICTING_IDS >/dev/null 2>&1 || true
  else
    echo "Error: Port $DB_HOST_PORT is already in use by a non-Docker process." >&2
    echo "Either stop that process or run with a different port, e.g.:" >&2
    echo "  DB_HOST_PORT=3307 $0" >&2
    exit 1
  fi
fi

# Resolve host APP port (Apache in container listens on 80; host maps to APP_HOST_PORT)
APP_HOST_PORT="${APP_HOST_PORT:-8000}"
export APP_HOST_PORT

if lsof -iTCP:"$APP_HOST_PORT" -sTCP:LISTEN -n -P >/dev/null 2>&1; then
  CONFLICTING_IDS=$(docker ps --format '{{.ID}} {{.Ports}}' | awk -v p=":${APP_HOST_PORT}->" 'index($0,p){print $1}') || true
  if [ -n "$CONFLICTING_IDS" ]; then
    echo "Port $APP_HOST_PORT is in use by Docker container(s): $CONFLICTING_IDS. Stopping them..."
    docker stop $CONFLICTING_IDS >/dev/null 2>&1 || true
    docker rm $CONFLICTING_IDS >/dev/null 2>&1 || true
  else
    echo "Error: Port $APP_HOST_PORT is already in use by a non-Docker process (e.g. php artisan serve)." >&2
    echo "Either stop that process or run with a different port, e.g.:" >&2
    echo "  APP_HOST_PORT=8001 $0" >&2
    exit 1
  fi
fi

# 1) Start containers
$COMPOSE up -d

# 2) Prepare app inside container
# Install composer deps
$COMPOSE exec app bash -lc "
  if ! command -v composer >/dev/null 2>&1; then
    echo 'Composer not found. Installing composer in container...'
    php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\"
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer || exit 1
    rm -f composer-setup.php
  fi
  composer --version
  composer install
"

# Ensure .env exists inside container (copy if needed)
$COMPOSE exec app bash -lc "[ -f .env ] || cp .env.example .env"

# Force MySQL config for Docker environment
$COMPOSE exec app bash -lc '
  set -e
  perl -pi -e "s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/" .env
  perl -pi -e "s/^DB_HOST=.*/DB_HOST=db/" .env || echo "DB_HOST=db" >> .env
  perl -pi -e "s/^DB_PORT=.*/DB_PORT=3306/" .env || echo "DB_PORT=3306" >> .env
  perl -pi -e "s/^DB_DATABASE=.*/DB_DATABASE=ulekare/" .env || echo "DB_DATABASE=ulekare" >> .env
  perl -pi -e "s/^DB_USERNAME=.*/DB_USERNAME=ulekare/" .env || echo "DB_USERNAME=ulekare" >> .env
  perl -pi -e "s/^DB_PASSWORD=.*/DB_PASSWORD=ulekare/" .env || echo "DB_PASSWORD=ulekare" >> .env
'

# Generate app key
$COMPOSE exec app php artisan key:generate

# Run migrations
$COMPOSE exec app php artisan migrate --force

# Clear caches just in case
$COMPOSE exec app php artisan optimize:clear

APP_URL="http://localhost:8000"
printf "\nNotes API is up at: %s (GraphQL at %s/graphql)\n" "$APP_URL" "$APP_URL"
printf "To view logs: ($COMPOSE logs -f app)\n"
