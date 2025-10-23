# Notes API – Run Guide

This is a Laravel + Lighthouse GraphQL backend for the Notes app.

- **GraphQL endpoint**: `http://localhost:8000/graphql`
- **Frontend**: The Ionic app points to this URL in `notes/src/app/graphql.module.ts`.

## Quick Start

- **Local (SQLite)**
  - From repo root:
    ```bash
    make api-local
    ```
  - Or from backend folder:
    ```bash
    cd notes-api && ./run-local.sh
    ```
  - Or from frontend folder:
    ```bash
    cd notes && npm run api:local
    ```

- **Docker (MariaDB)**
  - From repo root:
    ```bash
    make api-up
    ```
  - Or from backend folder:
    ```bash
    cd notes-api && ./run-docker.sh
    ```
  - Or from frontend folder:
    ```bash
    cd notes && npm run api:up
    ```

- **Logs / restart (Docker)**
  
  Use these Makefile shortcuts from the repo root to manage the API container quickly.

  - **api-logs**: Follow live Laravel logs to debug requests and errors.
  - **api-restart**: Restart only the API container after code/env changes.
  - **api-down**: Stop and remove the stack (API and DB containers).

  ```bash
  make api-logs
  make api-restart
  make api-down
  ```

  Tip: To clear caches inside the container:

  ```bash
  make api-cache
  ```

## cURL examples

- **List notes**
  ```bash
  curl -sS http://localhost:8000/graphql \
    -H 'Content-Type: application/json' \
    -d '{
      "operationName":"Notes",
      "variables": { "priority": "LOW" },
      "query": "query Notes($priority: Priority) { notes(priority: $priority) { id title content priority } }"
    }' | jq .
  ```

- **Create note**
  ```bash
  curl -sS http://localhost:8000/graphql \
    -H 'Content-Type: application/json' \
    -d '{
      "operationName":"CreateNote",
      "variables": { "input": { "title":"Hello", "content":"Body", "priority":"LOW" } },
      "query": "mutation CreateNote($input: NoteInput!) { createNote(input: $input) { id title content priority } }"
    }' | jq .
  ```

## Prerequisites

-   **Local run**
    -   PHP 8.2+
    -   Composer 2+
    -   SQLite (default) or MySQL if you prefer
-   **Docker run**
    -   Docker and Docker Compose

## 1) Run locally (SQLite, default)

1. Copy env and generate key

```bash
cp .env.example .env
composer install
composer cache:clear
php artisan key:generate
```

2. Ensure SQLite in `.env`

```env
DB_CONNECTION=sqlite
```

3. Create SQLite DB file and migrate

```bash
touch database/database.sqlite
composer migrate
```

4. Start the server

```bash
composer serve
```

Open GraphQL at http://localhost:8000/graphql

## 2) Run with Docker (MariaDB)

Defined at repo root `docker-compose.yml`.

1. Start containers (run inside `notes-api/`)

```bash
composer docker:up
```

2. Prepare app inside container

```bash
composer docker:app:install
composer docker:app:key
composer docker:app:migrate
```

App is available at http://localhost:8000 (GraphQL at `/graphql`).

Environment used by the container (already provided via compose):

-   `DB_CONNECTION=mysql`
-   `DB_HOST=db`
-   `DB_PORT=3306`
-   `DB_DATABASE=ulekare`
-   `DB_USERNAME=ulekare`
-   `DB_PASSWORD=ulekare`

## GraphQL examples

-   **Create note**

```graphql
mutation CreateNote($input: NoteInput!) {
    createNote(input: $input) {
        id
        title
        content
        priority
    }
}
# Variables
# { "input": { "title": "New", "content": "Body", "priority": "LOW" } }
```

-   **List notes**

```graphql
query Notes($priority: Priority) {
    notes(priority: $priority) {
        id
        title
        content
        priority
    }
}
# Variables
# { "priority": "LOW" }
```

## Troubleshooting

-   **500 on create**: Schema uses `@spread` on input; restart backend after schema changes and run `php artisan optimize:clear`.
-   **DB connection (Docker)**: Ensure `db` is healthy: `docker compose ps`.
-   **Frontend URL**: If you change backend host/port, update `notes/src/app/graphql.module.ts`.

## When you change backend code

### Local (php artisan serve)

- **PHP code only**: refresh the request; no restart needed.
- **Changed GraphQL schema or config**:
  ```bash
  composer cache:clear
  ```
- **Changed .env**:
  ```bash
  composer cache:clear
  # restart server if running
  composer serve
  ```
- **Changed Composer dependencies**:
  ```bash
  composer install
  composer dump-autoload
  composer cache:clear
  ```
- **DB changes (migrations/seeders)**:
  ```bash
  composer migrate
  # optional
  php artisan db:seed
  ```

### Docker (docker-compose)

- **PHP code only**: refresh; code is volume-mounted.
- **Changed GraphQL schema or config**:
  ```bash
  composer docker:app:cache:clear
  ```
- **Changed .env**:
  ```bash
  composer docker:app:cache:clear
  composer docker:restart
  ```
- **Changed Composer dependencies**:
  ```bash
  composer docker:app:install
  composer docker:app:cache:clear
  ```
- **Changed Dockerfile / PHP extensions**:
  ```bash
  composer docker:rebuild
  ```
- **DB changes (migrations/seeders)**:
  ```bash
  composer docker:app:migrate
  # optional
  docker compose exec app php artisan db:seed
  ```
- **Restart and logs**:
  ```bash
  composer docker:restart
  composer docker:logs
  ```

## Testing

- **Run test suite**:

```bash
composer test
```

## Quick commands

- **Start local server**: `composer serve`
- **Migrate DB (local)**: `composer migrate`
- **Clear caches (local)**: `composer cache:clear`
- **Start Docker stack**: `composer docker:up`
- **Install deps in container**: `composer docker:app:install`
- **Generate key in container**: `composer docker:app:key`
- **Migrate DB (Docker)**: `composer docker:app:migrate`
- **Clear caches (Docker)**: `composer docker:app:cache:clear`
- **Rebuild container**: `composer docker:rebuild`
- **Restart container**: `composer docker:restart`
- **Follow logs**: `composer docker:logs`

## Framework

This service is built with **Laravel 12** and **Lighthouse GraphQL**. See:

- Laravel: [https://laravel.com/docs](https://laravel.com/docs)
- Lighthouse: [https://lighthouse-php.com/](https://lighthouse-php.com/)
