#!/usr/bin/env bash
# Universal ML DevOps Framework Setup Script
# Automatically detects and configures for Linux or Windows (WSL/Git Bash/MSYS2)

set -euo pipefail

# =============================================================================
# PLATFORM DETECTION AND CONFIGURATION
# =============================================================================

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Icons for better UX
CHECKMARK="✅ "
CROSS="❌ "
WARNING="⚠️ "
INFO="ℹ️ "
ROCKET="🚀 "
GEAR="⚙️ "
COMPUTER="💻 "

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/setup.log"
PLATFORM=""
DISTRO=""
ARCHITECTURE=""
CONTAINER_RUNTIME=""
GPU_AVAILABLE=false
WSL_DETECTED=false

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${BLUE}${INFO}${NC} ${message}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}${CHECKMARK}${NC} ${message}"
            ;;
        "WARNING")
            echo -e "${YELLOW}${WARNING}${NC} ${message}"
            ;;
        "ERROR")
            echo -e "${RED}${CROSS}${NC} ${message}"
            ;;
        "DEBUG")
            [[ "${DEBUG:-}" == "true" ]] && echo -e "${PURPLE}[DEBUG]${NC} ${message}"
            ;;
    esac
    
    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

detect_platform() {
    log "INFO" "Detecting platform and environment..."
    
    # Detect OS
    case "$(uname -s)" in
        Linux*)
            PLATFORM="linux"
            detect_linux_distro
            ;;
        Darwin*)
            PLATFORM="macos"
            log "WARNING" "macOS detected. Some features may be limited."
            ;;
        CYGWIN*|MINGW*|MSYS*)
            PLATFORM="windows"
            detect_windows_environment
            ;;
        *)
            log "ERROR" "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
    
    # Detect architecture
    ARCHITECTURE=$(uname -m)
    case $ARCHITECTURE in
        x86_64|amd64)
            ARCHITECTURE="amd64"
            ;;
        aarch64|arm64)
            ARCHITECTURE="arm64"
            ;;
        *)
            log "WARNING" "Unsupported architecture: $ARCHITECTURE"
            ;;
    esac
    
    # Check if running in WSL
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi "microsoft" /proc/version 2>/dev/null; then
        WSL_DETECTED=true
        log "INFO" "WSL (Windows Subsystem for Linux) detected"
    fi
    
    log "SUCCESS" "Platform: $PLATFORM, Architecture: $ARCHITECTURE"
}

detect_linux_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO="$ID"
        log "INFO" "Linux distribution: $PRETTY_NAME"
    else
        DISTRO="unknown"
        log "WARNING" "Could not determine Linux distribution"
    fi
}

detect_windows_environment() {
    if command -v powershell.exe >/dev/null 2>&1; then
        log "INFO" "PowerShell detected - Windows with Git Bash/MSYS2"
    elif command -v cmd.exe >/dev/null 2>&1; then
        log "INFO" "Windows command prompt detected"
    else
        log "WARNING" "Windows environment detected but no PowerShell/CMD access"
    fi
}

check_prerequisites() {
    log "INFO" "Checking prerequisites for $PLATFORM..."
    
    local missing_deps=()
    
    # Universal dependencies
    command -v docker >/dev/null || missing_deps+=("docker")
    command -v git >/dev/null || missing_deps+=("git")
    
    # Check Docker Compose (v1 or v2)
    if ! command -v docker-compose >/dev/null && ! docker compose version >/dev/null 2>&1; then
        missing_deps+=("docker-compose")
    fi
    
    # Platform-specific dependencies
    case $PLATFORM in
        linux)
            command -v curl >/dev/null || missing_deps+=("curl")
            command -v wget >/dev/null || missing_deps+=("wget")
            ;;
        windows)
            # Check for PowerShell
            if ! command -v powershell.exe >/dev/null 2>&1; then
                log "WARNING" "PowerShell not accessible. Some features may not work."
            fi
            ;;
        macos)
            command -v brew >/dev/null || log "WARNING" "Homebrew not found. Manual installation may be required."
            ;;
    esac
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing dependencies: ${missing_deps[*]}"
        log "INFO" "Please install the missing dependencies and run this script again."
        
        case $PLATFORM in
            linux)
                suggest_linux_installation "${missing_deps[@]}"
                ;;
            windows)
                suggest_windows_installation "${missing_deps[@]}"
                ;;
            macos)
                suggest_macos_installation "${missing_deps[@]}"
                ;;
        esac
        
        exit 1
    fi
    
    log "SUCCESS" "All prerequisites are satisfied"
}

suggest_linux_installation() {
    local deps=("$@")
    log "INFO" "Suggested installation commands for $DISTRO:"
    
    case $DISTRO in
        ubuntu|debian)
            echo "sudo apt update && sudo apt install -y ${deps[*]}"
            if [[ " ${deps[*]} " =~ " docker " ]]; then
                echo "# Docker installation:"
                echo "curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
            fi
            ;;
        fedora|centos|rhel)
            echo "sudo dnf install -y ${deps[*]}"
            if [[ " ${deps[*]} " =~ " docker " ]]; then
                echo "# Docker installation:"
                echo "sudo dnf install -y docker-ce docker-ce-cli containerd.io"
            fi
            ;;
        arch)
            echo "sudo pacman -S ${deps[*]}"
            ;;
        *)
            echo "Please install: ${deps[*]}"
            ;;
    esac
}

suggest_windows_installation() {
    local deps=("$@")
    log "INFO" "Suggested installation for Windows:"
    
    echo "# Using Chocolatey (recommended):"
    echo "Set-ExecutionPolicy Bypass -Scope Process -Force"
    echo "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072"
    echo "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    echo "choco install ${deps[*]} -y"
    
    echo ""
    echo "# Or download manually:"
    for dep in "${deps[@]}"; do
        case $dep in
            docker)
                echo "Docker Desktop: https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
                ;;
            git)
                echo "Git for Windows: https://git-scm.com/download/win"
                ;;
        esac
    done
}

suggest_macos_installation() {
    local deps=("$@")
    log "INFO" "Suggested installation for macOS:"
    
    echo "# Using Homebrew:"
    echo "brew install ${deps[*]}"
    
    if [[ " ${deps[*]} " =~ " docker " ]]; then
        echo "# Docker Desktop for macOS:"
        echo "https://desktop.docker.com/mac/main/amd64/Docker.dmg"
    fi
}

detect_gpu() {
    log "INFO" "Detecting GPU availability..."
    
    case $PLATFORM in
        linux)
            if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
                GPU_AVAILABLE=true
                log "SUCCESS" "NVIDIA GPU detected and drivers are working"
                nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
            elif command -v rocm-smi >/dev/null 2>&1; then
                GPU_AVAILABLE=true
                log "SUCCESS" "AMD ROCm GPU detected"
            else
                log "INFO" "No GPU detected or drivers not installed"
            fi
            ;;
        windows)
            if command -v nvidia-smi.exe >/dev/null 2>&1 || [[ -f "/mnt/c/Program Files/NVIDIA Corporation/NVSMI/nvidia-smi.exe" ]]; then
                GPU_AVAILABLE=true
                log "SUCCESS" "NVIDIA GPU detected on Windows"
            elif $WSL_DETECTED && powershell.exe -Command "Get-WmiObject -Class Win32_VideoController | Where-Object {$_.Name -like '*NVIDIA*'}" 2>/dev/null | grep -q "NVIDIA"; then
                GPU_AVAILABLE=true
                log "SUCCESS" "NVIDIA GPU detected via WSL"
            else
                log "INFO" "No GPU detected on Windows"
            fi
            ;;
        macos)
            if system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Metal"; then
                GPU_AVAILABLE=true
                log "SUCCESS" "Metal GPU detected on macOS"
            else
                log "INFO" "No Metal GPU detected on macOS"
            fi
            ;;
    esac
}

detect_container_runtime() {
    log "INFO" "Detecting container runtime..."
    
    if command -v docker >/dev/null 2>&1; then
        CONTAINER_RUNTIME="docker"
        
        # Check if Docker daemon is running
        if docker info >/dev/null 2>&1; then
            log "SUCCESS" "Docker is running"
            
            # Check for GPU support in Docker
            if $GPU_AVAILABLE && docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi >/dev/null 2>&1; then
                log "SUCCESS" "Docker GPU support confirmed"
            elif $GPU_AVAILABLE; then
                log "WARNING" "GPU detected but Docker GPU support not working"
            fi
        else
            log "WARNING" "Docker is installed but not running"
            case $PLATFORM in
                linux)
                    log "INFO" "Try: sudo systemctl start docker"
                    ;;
                windows)
                    log "INFO" "Please start Docker Desktop"
                    ;;
                macos)
                    log "INFO" "Please start Docker Desktop"
                    ;;
            esac
        fi
    else
        log "ERROR" "Docker not found"
        exit 1
    fi
}

create_directory_structure() {
    log "INFO" "Creating directory structure..."
    
    local directories=(
        "volumes/postgres/data"
        "volumes/teamcity-server/data"
        "volumes/teamcity-server/logs"
        "volumes/teamcity-agent/conf"
        "volumes/gitlab/config"
        "volumes/gitlab/logs"
        "volumes/gitlab/data"
        "volumes/jenkins/data"
        "volumes/prometheus/data"
        "volumes/grafana/data"
        "volumes/mlflow/artifacts"
        "volumes/registry"
        "volumes/jupyterhub"
        "volumes/redis/data"
        "volumes/tensorboard"
        "volumes/pgladmin"
        "init-db"
        "k8s-manifests"
        "ml-models"
        "scripts"
        "monitoring/grafana/dashboards"
        "monitoring/grafana/provisioning/dashboards"
        "monitoring/grafana/provisioning/datasources"
        "monitoring/rules"
        "jenkins-config"
        "teamcity-config"
        "jupyter-config"
        "auth/registry"
        "certs"
        "backups"
        "logs"
        "data/training"
        "data/validation"
        "data/test"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        log "DEBUG" "Created directory: $dir"
    done
    
    log "SUCCESS" "Directory structure created"
}

generate_environment_config() {
    log "INFO" "Generating environment configuration..."
    
    cat > .env << EOF
# Universal ML DevOps Framework Configuration
# Auto-generated on $(date)
# Platform: $PLATFORM, Architecture: $ARCHITECTURE

# =============================================================================
# PLATFORM DETECTION
# =============================================================================
DETECTED_PLATFORM=$PLATFORM
DETECTED_ARCHITECTURE=$ARCHITECTURE
WSL_DETECTED=$WSL_DETECTED
GPU_AVAILABLE=$GPU_AVAILABLE
CONTAINER_RUNTIME=$CONTAINER_RUNTIME

# =============================================================================
# CORE SERVICE PORTS
# =============================================================================
POSTGRES_PORT=55432
REDIS_PORT=6379
TEAMCITY_PORT=8111
GITLAB_HTTP_PORT=8929
GITLAB_HTTPS_PORT=8443
GITLAB_SSH_PORT=2222
GITLAB_REGISTRY_PORT=5555
JENKINS_HTTP_PORT=8080
JENKINS_AGENT_PORT=50000
K8S_API_PORT=6443
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
MLFLOW_PORT=5000
TENSORBOARD_PORT=6006
REGISTRY_PORT=5000
PGLADMIN_PORT=5050
JUPYTERHUB_PORT=8888
NODE_EXPORTER_PORT=9100
GPU_EXPORTER_PORT=9445

# =============================================================================
# DATABASE CONFIGURATION
# =============================================================================
POSTGRES_ROOT_PASSWORD=rootpass
POSTGRES_DB_TEAMCITY=teamcity
POSTGRES_USER_TEAMCITY=teamcity
POSTGRES_PASSWORD_TEAMCITY=teamcitypass
POSTGRES_DB_GITLAB=gitlabhq_production
POSTGRES_USER_GITLAB=gitlab
POSTGRES_PASSWORD_GITLAB=gitlabpass
POSTGRES_DB_MLFLOW=mlflow
POSTGRES_USER_MLFLOW=mlflow
POSTGRES_PASSWORD_MLFLOW=mlflowpass

# =============================================================================
# SERVICE AUTHENTICATION
# =============================================================================
GITLAB_ROOT_PASSWORD=rootpassword123
GITLAB_HOST=localhost
JENKINS_ADMIN_USER=admin
JENKINS_ADMIN_PASSWORD=admin
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
PGLADMIN_EMAIL=admin@admin.com
PGLADMIN_PASSWORD=admin
JUPYTERHUB_ADMIN_USER=admin
REDIS_PASSWORD=redispass

# =============================================================================
# ML CONFIGURATION
# =============================================================================
MLFLOW_WORKERS=2
JUPYTER_CONTAINER=quay.io/jupyter/tensorflow-notebook:latest
MODEL_REGISTRY_URL=localhost:5000

# GPU Configuration
NVIDIA_VISIBLE_DEVICES=${GPU_AVAILABLE:+all}
NVIDIA_DRIVER_CAPABILITIES=${GPU_AVAILABLE:+compute,utility}
CUDA_VERSION=11.8

# =============================================================================
# MONITORING CONFIGURATION
# =============================================================================
PROMETHEUS_RETENTION=15d
GRAFANA_INSTALL_PLUGINS=grafana-piechart-panel,grafana-worldmap-panel

# =============================================================================
# DEVELOPMENT CONFIGURATION
# =============================================================================
DEBUG=false
LOG_LEVEL=INFO
COMPOSE_PROJECT_NAME=ml-devops
COMPOSE_HTTP_TIMEOUT=120

# =============================================================================
# PERFORMANCE TUNING
# =============================================================================
# Adjust based on system resources
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_MAX_CONNECTIONS=100
JENKINS_JAVA_OPTS=-Xmx2g -Xms512m
GITLAB_MEMORY_LIMIT=4g
TEAMCITY_MEMORY_LIMIT=2g

# =============================================================================
# PLATFORM-SPECIFIC CONFIGURATIONS
# =============================================================================
EOF

    # Add platform-specific configurations
    case $PLATFORM in
        linux)
            cat >> .env << EOF
# Linux-specific configuration
DOCKER_SOCKET_PATH=/var/run/docker.sock
HOST_PROC_PATH=/proc
HOST_SYS_PATH=/sys
HOST_DEV_PATH=/dev
EOF
            ;;
        windows)
            cat >> .env << EOF
# Windows-specific configuration (WSL/Git Bash)
DOCKER_SOCKET_PATH=/var/run/docker.sock
# Note: Paths automatically adapted by Docker Desktop
WINDOWS_HOST=true
EOF
            ;;
        macos)
            cat >> .env << EOF
# macOS-specific configuration
DOCKER_SOCKET_PATH=/var/run/docker.sock
MACOS_HOST=true
EOF
            ;;
    esac
    
    log "SUCCESS" "Environment configuration generated: .env"
}

generate_compose_config() {
    log "INFO" "Generating Docker Compose configuration..."
    
    # Create platform-specific overrides
    case $PLATFORM in
        linux)
            cat > docker-compose.override.yml << 'EOF'
# Linux-specific Docker Compose overrides

services:
  node-exporter:
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
      
  jenkins:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      
  teamcity-agent:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      
  kubernetes-cluster:
    volumes:
      - /dev:/dev
      - /lib/modules:/lib/modules:ro
EOF
            ;;
        windows)
            cat > docker-compose.override.yml << 'EOF'
# Windows-specific Docker Compose overrides

services:
  node-exporter:
    # Windows paths handled by Docker Desktop
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($|/)'
      
  jenkins:
    volumes:
      # Docker Desktop handles socket mounting on Windows
      - /var/run/docker.sock:/var/run/docker.sock
      
  teamcity-agent:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF
            ;;
    esac
    
    log "SUCCESS" "Platform-specific Docker Compose configuration generated"
}

generate_monitoring_config() {
    log "INFO" "Generating monitoring configuration..."
    
    # Universal Prometheus configuration
    cat > monitoring/prometheus-universal.yml << 'EOF'
# Universal Prometheus Configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'ml-devops-universal'

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    scrape_interval: 15s

  - job_name: 'jenkins'
    static_configs:
      - targets: ['jenkins-master:8080']
    metrics_path: /prometheus
    scrape_interval: 30s

  - job_name: 'gitlab'
    static_configs:
      - targets: ['gitlab:8929']
    metrics_path: /-/metrics
    scrape_interval: 30s

  - job_name: 'teamcity'
    static_configs:
      - targets: ['teamcity-server:8111']
    metrics_path: /app/metrics/prometheus
    scrape_interval: 30s

  - job_name: 'mlflow'
    static_configs:
      - targets: ['mlflow-server:5000']
    metrics_path: /metrics
    scrape_interval: 30s

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-db:5432']
    scrape_interval: 30s

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-cache:6379']
    scrape_interval: 30s

  - job_name: 'docker-registry'
    static_configs:
      - targets: ['docker-registry:5000']
    scrape_interval: 30s
EOF

    # Add GPU monitoring if available
    if $GPU_AVAILABLE; then
        cat >> monitoring/prometheus-universal.yml << 'EOF'

  - job_name: 'gpu-exporter'
    static_configs:
      - targets: ['gpu-exporter:9445']
    scrape_interval: 15s
EOF
    fi

    # Grafana datasource configuration
    mkdir -p monitoring/grafana/provisioning/datasources
    cat > monitoring/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    access: proxy
    isDefault: true
    jsonData:
      timeInterval: "5s"
      httpMethod: GET
EOF

    log "SUCCESS" "Monitoring configuration generated"
}

generate_init_scripts() {
    log "INFO" "Generating initialization scripts..."
    
    # Database initialization
    cat > init-db/init.sql << 'EOF'
-- Universal Database Initialization Script

-- Create TeamCity database and user
CREATE DATABASE teamcity;
CREATE USER teamcity WITH ENCRYPTED PASSWORD 'teamcitypass';
GRANT ALL PRIVILEGES ON DATABASE teamcity TO teamcity;

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

-- Switch to MLflow database for tables
\c mlflow;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOF

    # MLflow startup script
    cat > scripts/mlflow-entrypoint.sh << 'EOF'
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
EOF
    chmod +x scripts/mlflow-entrypoint.sh

    # Sample ML training script
    cat > ml-models/universal_train.py << 'EOF'
#!/usr/bin/env python3
"""
Universal ML Training Script
Works across all platforms with automatic GPU detection
"""

import os
import sys
import platform
import mlflow
import mlflow.sklearn
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
from sklearn.datasets import make_classification

def detect_compute_environment():
    """Detect available compute resources"""
    env_info = {
        'platform': platform.system(),
        'architecture': platform.machine(),
        'python_version': platform.python_version(),
        'gpu_available': False,
        'gpu_type': None
    }
    
    # Check for GPU availability
    try:
        import tensorflow as tf
        if tf.config.list_physical_devices('GPU'):
            env_info['gpu_available'] = True
            env_info['gpu_type'] = 'CUDA'
            print("✅ TensorFlow GPU detected")
        else:
            print("ℹ️ TensorFlow using CPU")
    except ImportError:
        try:
            import torch
            if torch.cuda.is_available():
                env_info['gpu_available'] = True
                env_info['gpu_type'] = 'CUDA'
                print("✅ PyTorch CUDA detected")
            else:
                print("ℹ️ PyTorch using CPU")
        except ImportError:
            print("ℹ️ No GPU ML libraries detected")
    
    return env_info

def train_model():
    """Universal model training function"""
    
    # Environment detection
    env_info = detect_compute_environment()
    print(f"🖥️ Platform: {env_info['platform']} {env_info['architecture']}")
    print(f"🐍 Python: {env_info['python_version']}")
    print(f"🔧 GPU Available: {env_info['gpu_available']}")
    
    # MLflow setup
    mlflow.set_tracking_uri(os.getenv('MLFLOW_TRACKING_URI', 'http://localhost:5000'))
    mlflow.set_experiment('universal-ml-experiment')
    
    with mlflow.start_run():
        # Log environment info
        mlflow.log_params(env_info)
        
        # Generate sample data
        print("📊 Generating sample dataset...")
        X, y = make_classification(
            n_samples=1000,
            n_features=10,
            n_informative=5,
            n_redundant=2,
            n_classes=2,
            random_state=42
        )
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        # Train model
        print("🤖 Training model...")
        model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            random_state=42
        )
        model.fit(X_train, y_train)
        
        # Evaluate model
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        # Log results
        mlflow.log_metric('accuracy', accuracy)
        mlflow.log_metric('train_samples', len(X_train))
        mlflow.log_metric('test_samples', len(X_test))
        
        # Log model
        mlflow.sklearn.log_model(
            model,
            "random_forest_model",
            registered_model_name="universal-ml-model"
        )
        
        print(f"✅ Model trained successfully!")
        print(f"📈 Accuracy: {accuracy:.4f}")
        print(f"🔍 Classification Report:")
        print(classification_report(y_test, y_pred))
        
        return accuracy

if __name__ == "__main__":
    train_model()
EOF
    chmod +x ml-models/universal_train.py

    log "SUCCESS" "Initialization scripts generated"
}

setup_permissions() {
    log "INFO" "Setting up permissions..."
    
    case $PLATFORM in
        linux)
            # Set ownership for Docker volumes
            if [[ $EUID -eq 0 ]]; then
                chown -R 1000:1000 volumes/jenkins/data 2>/dev/null || true
                chown -R 999:999 volumes/gitlab/data 2>/dev/null || true
            else
                log "INFO" "Running as non-root. Some permission adjustments may be needed."
            fi
            ;;
        windows|macos)
            # Docker Desktop handles permissions automatically
            log "INFO" "Docker Desktop handles permissions automatically"
            ;;
    esac
    
    # Make scripts executable
    find scripts -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find ml-models -type f -name "*.py" -exec chmod +x {} \; 2>/dev/null || true
    
    log "SUCCESS" "Permissions configured"
}

start_services() {
    log "INFO" "Starting ML DevOps Framework services..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log "ERROR" "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Determine compose command and version
    local compose_cmd=""
    local compose_version=""
    local supports_profiles=false
    
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
        compose_version=$(docker-compose version --short 2>/dev/null || echo "unknown")
        # Check if version supports profiles (v1.28.0+)
        if [[ "$compose_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            local major=$(echo $compose_version | cut -d. -f1)
            local minor=$(echo $compose_version | cut -d. -f2)
            if [[ $major -gt 1 ]] || [[ $major -eq 1 && $minor -ge 28 ]]; then
                supports_profiles=true
            fi
        fi
    elif docker compose version >/dev/null 2>&1; then
        compose_cmd="docker compose"
        supports_profiles=true  # Docker Compose v2 always supports profiles
    else
        log "ERROR" "Neither docker-compose nor 'docker compose' found"
        exit 1
    fi
    
    log "INFO" "Using: $compose_cmd (profiles: $supports_profiles)"
    
    # Build compose command
    local compose_args=("up" "-d")
    
    # Add profiles if supported and GPU is available
    if $supports_profiles && $GPU_AVAILABLE; then
        compose_args+=("--profile" "gpu")
        log "INFO" "GPU profile enabled"
    elif $GPU_AVAILABLE && ! $supports_profiles; then
        log "WARNING" "GPU detected but Docker Compose version doesn't support profiles. GPU services will be started manually."
    fi
    
    # Start services in stages for better reliability
    log "INFO" "Starting core infrastructure services..."
    
    # Stage 1: Core infrastructure
    if ! $compose_cmd "${compose_args[@]}" postgres redis registry; then
        log "ERROR" "Failed to start core infrastructure services"
        log "INFO" "Trying without registry service..."
        $compose_cmd up -d postgres redis || {
            log "ERROR" "Failed to start even basic services. Please check Docker and try again."
            exit 1
        }
    fi
    
    # Wait for database
    log "INFO" "Waiting for database to be ready..."
    local db_ready=false
    for i in {1..30}; do
        if docker exec postgres-db pg_isready -U postgres >/dev/null 2>&1; then
            db_ready=true
            break
        fi
        sleep 5
        log "DEBUG" "Database not ready, attempt $i/30"
    done
    
    if ! $db_ready; then
        log "WARNING" "Database took longer than expected to start"
    else
        log "SUCCESS" "Database is ready"
    fi
    
    # Stage 2: CI services (more resource intensive)
    log "INFO" "Starting CI services..."
    if ! $compose_cmd "${compose_args[@]}" teamcity-server gitlab; then
        log "WARNING" "CI services failed to start together, trying individually..."
        $compose_cmd up -d teamcity-server || log "WARNING" "TeamCity failed to start"
        sleep 10
        $compose_cmd up -d gitlab || log "WARNING" "GitLab failed to start"
    fi
    
    # Wait for CI services
    log "INFO" "Waiting for CI services to initialize (this may take several minutes)..."
    sleep 30
    
    # Stage 3: CD and monitoring services
    log "INFO" "Starting CD and monitoring services..."
    if ! $compose_cmd "${compose_args[@]}" jenkins prometheus grafana node-exporter; then
        log "WARNING" "Some CD/monitoring services failed, continuing with available services..."
        $compose_cmd up -d jenkins || log "WARNING" "Jenkins failed to start"
        $compose_cmd up -d prometheus || log "WARNING" "Prometheus failed to start"
        $compose_cmd up -d grafana || log "WARNING" "Grafana failed to start"
        $compose_cmd up -d node-exporter || log "WARNING" "Node exporter failed to start"
    fi
    
    # Stage 4: ML services
    log "INFO" "Starting ML services..."
    if ! $compose_cmd "${compose_args[@]}" mlflow tensorboard jupyterhub teamcity-agent; then
        log "WARNING" "Some ML services failed, starting individually..."
        $compose_cmd up -d mlflow || log "WARNING" "MLflow failed to start"
        $compose_cmd up -d tensorboard || log "WARNING" "TensorBoard failed to start"
        $compose_cmd up -d jupyterhub || log "WARNING" "JupyterHub failed to start"
        $compose_cmd up -d teamcity-agent || log "WARNING" "TeamCity agent failed to start"
    fi
    
    # Stage 5: GPU services (if supported and available)
    if $GPU_AVAILABLE; then
        if $supports_profiles; then
            log "INFO" "Starting GPU services..."
            $compose_cmd --profile gpu up -d gpu-exporter || log "WARNING" "GPU exporter failed to start"
        else
            log "INFO" "Manually starting GPU-enabled services..."
            # Manually start GPU services by modifying environment
            COMPOSE_PROFILES=gpu $compose_cmd up -d gpu-exporter || log "WARNING" "GPU services not available in this Compose version"
        fi
    fi
    
    # Stage 6: Remaining services
    log "INFO" "Starting remaining services..."
    $compose_cmd up -d pgadmin || log "WARNING" "PgAdmin failed to start"
    
    # Show service status
    log "INFO" "Service startup completed. Checking status..."
    $compose_cmd ps
    
    log "SUCCESS" "ML DevOps Framework services started!"
}

wait_for_services() {
    log "INFO" "Waiting for services to be ready..."
    
    local services=(
        "postgres-db:5432"
        "redis-cache:6379"
        "teamcity-server:8111"
        "gitlab:8929"
        "jenkins-master:8080"
        "prometheus:9090"
        "grafana:3000"
        "mlflow-server:5000"
    )
    
    local max_wait=300  # 5 minutes
    local start_time=$(date +%s)
    
    for service_port in "${services[@]}"; do
        IFS=':' read -r service port <<< "$service_port"
        log "INFO" "Checking $service on port $port..."
        
        while true; do
            local current_time=$(date +%s)
            if (( current_time - start_time > max_wait )); then
                log "WARNING" "Timeout waiting for $service"
                break
            fi
            
            if docker exec "$service" sh -c "command -v nc >/dev/null && nc -z localhost $port" 2>/dev/null ||
               curl -f "http://localhost:$port" >/dev/null 2>&1; then
                log "SUCCESS" "$service is ready"
                break
            fi
            
            sleep 10
        done
    done
}

display_access_info() {
    log "SUCCESS" "ML DevOps Framework is ready!"
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}🚀 ML DevOps Framework - Universal Setup${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${BLUE}📍 Platform:${NC} $PLATFORM ($ARCHITECTURE)"
    echo -e "${BLUE}🐳 Container Runtime:${NC} $CONTAINER_RUNTIME"
    echo -e "${BLUE}🖥️ GPU Available:${NC} $GPU_AVAILABLE"
    if $WSL_DETECTED; then
        echo -e "${BLUE}🐧 WSL Detected:${NC} Yes"
    fi
    
    echo ""
    echo -e "${CYAN}📊 Service Access URLs:${NC}"
    echo "────────────────────────"
    echo -e "${BLUE}TeamCity:${NC}         http://localhost:8111"
    echo -e "${BLUE}GitLab:${NC}           http://localhost:8929 (root/rootpassword123)"
    echo -e "${BLUE}Jenkins:${NC}          http://localhost:8080 (admin/admin)"
    echo -e "${BLUE}Prometheus:${NC}       http://localhost:9090"
    echo -e "${BLUE}Grafana:${NC}          http://localhost:3000 (admin/admin)"
    echo -e "${BLUE}MLflow:${NC}           http://localhost:5000"
    echo -e "${BLUE}TensorBoard:${NC}      http://localhost:6006"
    echo -e "${BLUE}JupyterHub:${NC}       http://localhost:8888"
    echo -e "${BLUE}Docker Registry:${NC}  http://localhost:5000"
    echo -e "${BLUE}PgAdmin:${NC}          http://localhost:5050 (admin@admin.com/admin)"
    
    echo ""
    echo -e "${YELLOW}🎯 Next Steps:${NC}"
    echo "1. Configure TeamCity: http://localhost:8111"
    echo "2. Set up GitLab projects: http://localhost:8929"
    echo "3. Configure Jenkins pipelines: http://localhost:8080"
    echo "4. Monitor with Grafana: http://localhost:3000"
    
    echo ""
    echo -e "${GREEN}🧪 Test ML Training:${NC}"
    echo "cd ml-models && python universal_train.py"
    
    if $GPU_AVAILABLE; then
        echo ""
        echo -e "${GREEN}🖥️ GPU Status:${NC}"
        case $PLATFORM in
            linux)
                nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null || true
                ;;
            windows)
                if command -v nvidia-smi.exe >/dev/null 2>&1; then
                    nvidia-smi.exe --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null || true
                fi
                ;;
        esac
    fi
    
    echo ""
    echo -e "${PURPLE}📝 Management Commands:${NC}"
    echo "./setup.sh start|stop|restart|status|logs|update"
    echo ""
}

# =============================================================================
# MAIN EXECUTION LOGIC
# =============================================================================

main() {
    local action="${1:-install}"
    
    # Initialize logging
    echo "Starting ML DevOps Framework Universal Setup..." > "$LOG_FILE"
    
    case $action in
        "install"|"setup"|"")
            echo -e "${GREEN}========================================${NC}"
            echo -e "${GREEN}🚀 ML DevOps Framework Universal Setup${NC}"
            echo -e "${GREEN}========================================${NC}"
            echo ""
            
            detect_platform
            check_prerequisites
            detect_gpu
            detect_container_runtime
            create_directory_structure
            generate_environment_config
            generate_compose_config
            generate_monitoring_config
            generate_init_scripts
            setup_permissions
            start_services
            wait_for_services
            display_access_info
            ;;
        "start")
            log "INFO" "Starting services..."
            start_services
            wait_for_services
            display_access_info
            ;;
        "stop")
            log "INFO" "Stopping services..."
            docker-compose down
            log "SUCCESS" "Services stopped"
            ;;
        "restart")
            log "INFO" "Restarting services..."
            docker-compose restart
            wait_for_services
            log "SUCCESS" "Services restarted"
            ;;
        "status")
            docker-compose ps
            ;;
        "logs")
            local service="${2:-}"
            if [[ -n "$service" ]]; then
                docker-compose logs -f "$service"
            else
                docker-compose logs
            fi
            ;;
        "update")
            log "INFO" "Updating services..."
            docker-compose pull
            docker-compose up -d --remove-orphans
            log "SUCCESS" "Services updated"
            ;;
        "clean")
            log "WARNING" "This will remove all containers and volumes. Are you sure? (y/N)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                docker-compose down -v --remove-orphans
                docker system prune -f
                log "SUCCESS" "Cleanup completed"
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Universal ML DevOps Framework Setup"
            echo ""
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  install, setup    - Full installation and setup (default)"
            echo "  start            - Start all services"
            echo "  stop             - Stop all services"
            echo "  restart          - Restart all services"
            echo "  status           - Show service status"
            echo "  logs [SERVICE]   - Show logs (optionally for specific service)"
            echo "  update           - Update service images and restart"
            echo "  clean            - Remove all containers and volumes"
            echo "  help             - Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  DEBUG=true       - Enable debug output"
            echo ""
            ;;
        *)
            log "ERROR" "Unknown command: $action"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Handle script arguments and execute main function
main "$@"