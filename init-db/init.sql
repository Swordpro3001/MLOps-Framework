-- Universal Database Initialization Script

-- Create GitLab database and user
CREATE DATABASE gitlabhq_production;
CREATE USER gitlab WITH ENCRYPTED PASSWORD '${POSTGRES_PASSWORD_GITLAB}';
GRANT ALL PRIVILEGES ON DATABASE gitlabhq_production TO gitlab;

-- Create MLflow database and user
CREATE DATABASE mlflow;
CREATE USER mlflow WITH ENCRYPTED PASSWORD '${POSTGRES_PASSWORD_MLFLOW}';
GRANT ALL PRIVILEGES ON DATABASE mlflow TO mlflow;

-- Switch to GitLab database for extensions
\c gitlabhq_production;
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Switch to MLflow database for tables
\c mlflow;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
