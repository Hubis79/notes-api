#!/usr/bin/env bash
set -euo pipefail

# Notes API Docker setup and serve helper (uses repo-root docker-compose.yml)
# Usage: ./run-docker.sh

# Ensure docker is available
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not on PATH." >&2
  exit 1
fi

# Determine repo root (docker-compose.yml is one level up from notes-api/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$REPO_ROOT/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Error: docker-compose.yml not found at $COMPOSE_FILE" >&2
  exit 1
fi

# 1) Start containers
( cd "$REPO_ROOT" && docker compose up -d )

# 2) Prepare app inside container
# Install composer deps
( cd "$REPO_ROOT" && docker compose exec app bash -lc "
  if ! command -v composer >/dev/null 2>&1; then
    echo 'Composer not found. Installing composer in container...'
    php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\"
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer || exit 1
    rm -f composer-setup.php
  fi
  composer --version
  composer install
" )

# Ensure .env exists inside container (copy if needed)
( cd "$REPO_ROOT" && docker compose exec app bash -lc "[ -f .env ] || cp .env.example .env" )

# Generate app key
( cd "$REPO_ROOT" && docker compose exec app php artisan key:generate )

# Run migrations
( cd "$REPO_ROOT" && docker compose exec app php artisan migrate --force )

# Clear caches just in case
( cd "$REPO_ROOT" && docker compose exec app php artisan optimize:clear )

APP_URL="http://localhost:8000"
printf "\nNotes API is up at: %s (GraphQL at %s/graphql)\n" "$APP_URL" "$APP_URL"
printf "To view logs: (cd %s && docker compose logs -f app)\n" "$REPO_ROOT"
