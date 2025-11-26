-- Universal Database Initialization Script

-- Create GitLab database and user
CREATE DATABASE gitlabhq_production;
CREATE USER gitlab WITH ENCRYPTED PASSWORD 'gitlabpass';
GRANT ALL PRIVILEGES ON DATABASE gitlabhq_production TO gitlab;

-- Create MLflow database and user
CREATE DATABASE mlflow;
CREATE USER mlflow WITH ENCRYPTED PASSWORD 'mlflowpass';
GRANT ALL PRIVILEGES ON DATABASE mlflow TO mlflow;

-- Switch to GitLab database for extensions
\c gitlabhq_production;
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gist";
ALTER DATABASE gitlabhq_production OWNER TO gitlab;

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO gitlab;

-- Switch to MLflow database for tables
\c mlflow;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
ALTER DATABASE mlflow OWNER TO mlflow;
GRANT ALL ON SCHEMA public TO mlflow;
