#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Notes API local setup (SQLite) and serve helper
# Usage: ./run-local.sh

if ! command -v composer >/dev/null 2>&1; then
  echo "Error: composer is not installed or not on PATH." >&2
  echo "On macOS: brew install composer" >&2
  exit 1
fi

# 1) one-time setup (idempotent)
if [ ! -f .env ]; then
  cp .env.example .env
fi

composer install
composer cache:clear || true

if ! grep -q '^APP_KEY=' .env || grep -q '^APP_KEY=\s*$' .env; then
  php artisan key:generate
fi

# ensure SQLite
if ! grep -q '^DB_CONNECTION=sqlite' .env; then
  echo "Warning: DB_CONNECTION is not sqlite in .env; switching to sqlite for local run" >&2
  perl -pi -e 's/^DB_CONNECTION=.*/DB_CONNECTION=sqlite/' .env
fi

# sqlite file
mkdir -p database
: > database/database.sqlite

# migrate
composer migrate

# 2) serve
php artisan serve --host=127.0.0.1 --port=8000
