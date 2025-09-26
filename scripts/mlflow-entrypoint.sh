#!/bin/bash
# MLflow startup script with database migration

set -e

echo "Starting MLflow server..."

# Wait for database
echo "Waiting for database connection..."
while ! python -c "import psycopg2; psycopg2.connect('${MLFLOW_BACKEND_STORE_URI}')" 2>/dev/null; do
    echo "Database not ready, waiting..."
    sleep 5
done

echo "Database connected successfully"

# Initialize/upgrade database schema
echo "Running database migration..."
mlflow db upgrade "${MLFLOW_BACKEND_STORE_URI}"

echo "Starting MLflow server on ${MLFLOW_HOST}:${MLFLOW_PORT}"
exec mlflow server \
    --backend-store-uri "${MLFLOW_BACKEND_STORE_URI}" \
    --default-artifact-root "${MLFLOW_DEFAULT_ARTIFACT_ROOT}" \
    --host "${MLFLOW_HOST}" \
    --port "${MLFLOW_PORT}" \
    --workers "${MLFLOW_WORKERS:-2}"
