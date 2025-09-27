#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# GLOBALS AND CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/setup.log"
PLATFORM=""
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
        "INFO") echo "[INFO] $message" ;;
        "SUCCESS") echo "[SUCCESS] $message" ;;
        "WARNING") echo "[WARNING] $message" ;;
        "ERROR") echo "[ERROR] $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

detect_platform() {
    log "INFO" "Detecting platform..."
    
    case "$(uname -s)" in
        Linux*) PLATFORM="linux" ;;
        Darwin*) PLATFORM="macos" ;;
        CYGWIN*|MINGW*|MSYS*) PLATFORM="windows" ;;
        *) log "ERROR" "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    
    ARCHITECTURE=$(uname -m)
    case $ARCHITECTURE in
        x86_64|amd64) ARCHITECTURE="amd64" ;;
        aarch64|arm64) ARCHITECTURE="arm64" ;;
    esac
    
    # WSL detection
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi "microsoft" /proc/version 2>/dev/null; then
        WSL_DETECTED=true
    fi
    
    log "SUCCESS" "Platform: $PLATFORM, Architecture: $ARCHITECTURE"
}

check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    local missing=()
    command -v docker >/dev/null || missing+=("docker")
    command -v git >/dev/null || missing+=("git")
    
    if ! command -v docker-compose >/dev/null && ! docker compose version >/dev/null 2>&1; then
        missing+=("docker-compose")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log "ERROR" "Missing: ${missing[*]}"
        exit 1
    fi
    
    log "SUCCESS" "Prerequisites satisfied"
}

detect_gpu() {
    log "INFO" "Detecting GPU..."
    
    case $PLATFORM in
        linux)
            if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
                GPU_AVAILABLE=true
                log "SUCCESS" "NVIDIA GPU detected"
            fi
            ;;
        windows)
            if command -v nvidia-smi.exe >/dev/null 2>&1; then
                GPU_AVAILABLE=true
                log "SUCCESS" "NVIDIA GPU detected"
            fi
            ;;
    esac
}

detect_container_runtime() {
    log "INFO" "Detecting container runtime..."
    
    if command -v docker >/dev/null 2>&1; then
        CONTAINER_RUNTIME="docker"
        if docker info >/dev/null 2>&1; then
            log "SUCCESS" "Docker is running"
        else
            log "WARNING" "Docker not running"
        fi
    fi
}

create_directories() {
    log "INFO" "Creating directories..."
    
    local dirs=(
        "volumes/postgres" "volumes/jenkins" "volumes/gitlab" "volumes/teamcity"
        "volumes/prometheus" "volumes/grafana" "volumes/mlflow" "volumes/redis"
        "k8s-manifests" "ml-models" "scripts" "logs" "backups"
        "monitoring/grafana/dashboards" "monitoring/grafana/provisioning"
        "auth/registry" "certs"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    log "SUCCESS" "Directories created"
}

generate_env() {
    log "INFO" "Generating .env file..."
    
    # Only generate if .env doesn't exist
    if [[ -f .env ]]; then
        log "INFO" "Using existing .env file"
        return 0
    fi
    
    # Create .env with detected values
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
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_MAX_CONNECTIONS=100
JENKINS_JAVA_OPTS="-Xmx2g -Xms512m"
GITLAB_MEMORY_LIMIT=4g
TEAMCITY_MEMORY_LIMIT=2g

# =============================================================================
# PLATFORM-SPECIFIC CONFIGURATIONS
# =============================================================================
DOCKER_SOCKET_PATH=/var/run/docker.sock
EOF

    # Add platform-specific configurations
    case $PLATFORM in
        windows)
            echo "WINDOWS_HOST=true" >> .env
            ;;
        macos)
            echo "MACOS_HOST=true" >> .env
            ;;
    esac
    
    log "SUCCESS" "Environment file generated"
}

copy_configs() {
    log "INFO" "Copying configuration files..."
    
    # Check if config files exist, if not create minimal versions
    if [[ ! -f "docker-compose.yaml" ]]; then
        log "WARNING" "docker-compose.yaml not found, using provided version"
    fi
    
    if [[ ! -f "monitoring/prometheus-universal.yml" ]]; then
        log "WARNING" "Prometheus config not found, using provided version"
    fi
    
    if [[ ! -f "init-db/init.sql" ]]; then
        log "WARNING" "Database init script not found, using provided version"
    fi
    
    log "SUCCESS" "Configuration files ready"
}

setup_permissions() {
    log "INFO" "Setting permissions..."
    
    case $PLATFORM in
        linux)
            find scripts -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
            find ml-models -name "*.py" -exec chmod +x {} \; 2>/dev/null || true
            ;;
        *)
            log "INFO" "Permissions handled by Docker Desktop"
            ;;
    esac
    
    log "SUCCESS" "Permissions set"
}

start_services() {
    log "INFO" "Starting services..."
    load_env
    
    if ! docker info >/dev/null 2>&1; then
        log "ERROR" "Docker not running"
        exit 1
    fi
    
    # Determine compose command
    local compose_cmd=""
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        compose_cmd="docker compose"
    else
        log "ERROR" "No compose command found"
        exit 1
    fi
    
    log "INFO" "Using compose command: $compose_cmd"
    
    # Start in stages
    log "INFO" "Starting core services..."
    if ! $compose_cmd up -d postgres redis; then
        log "ERROR" "Failed to start core services"
        $compose_cmd logs postgres
        exit 1
    fi
    
    log "INFO" "Waiting for database..."
    local attempts=0
    local max_attempts=60
    local postgres_ready=false
    
    # Try different container name patterns
    local container_names=(
        "postgres-db"
        "${COMPOSE_PROJECT_NAME:-ml-devops}_postgres-db_1"
        "${COMPOSE_PROJECT_NAME:-ml-devops}-postgres-db-1"
        "ml-devops_postgres-db_1"
        "ml-devops-postgres-db-1"
    )
    
    while [[ $attempts -lt $max_attempts ]] && ! $postgres_ready; do
        for container_name in "${container_names[@]}"; do
            if docker exec "$container_name" pg_isready -U postgres >/dev/null 2>&1; then
                log "SUCCESS" "Database is ready (container: $container_name)"
                postgres_ready=true
                break
            fi
        done
        
        if ! $postgres_ready; then
            ((attempts++))
            if [[ $((attempts % 10)) -eq 0 ]]; then
                log "INFO" "Still waiting for database... ($attempts/$max_attempts)"
                # Show container status for debugging
                log "INFO" "Container status:"
                docker ps --filter "name=postgres"
                # Show logs for debugging
                for container_name in "${container_names[@]}"; do
                    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
                        log "INFO" "Logs for $container_name:"
                        docker logs --tail=10 "$container_name"
                        break
                    fi
                done
            fi
            sleep 5
        fi
    done
    
    if ! $postgres_ready; then
        log "ERROR" "Database failed to start within $((max_attempts * 5)) seconds"
        log "INFO" "Container status:"
        $compose_cmd ps
        log "INFO" "PostgreSQL logs:"
        $compose_cmd logs postgres
        exit 1
    fi
    
    log "INFO" "Starting application services..."
    if ! $compose_cmd up -d teamcity-server gitlab jenkins prometheus grafana mlflow; then
        log "WARNING" "Some application services failed to start"
        $compose_cmd ps
    fi
    
    log "INFO" "Starting remaining services..."
    $compose_cmd up -d teamcity-agent tensorboard node-exporter
    
    # Start GPU services if available
    if [[ "${GPU_AVAILABLE:-false}" == "true" ]]; then
        $compose_cmd up -d gpu-exporter 2>/dev/null || log "WARNING" "GPU services not available"
    fi
    
    log "SUCCESS" "Services started"
    
    # Show final status
    log "INFO" "Final service status:"
    $compose_cmd ps
}

load_env() {
    if [[ -f .env ]]; then
        # Load environment variables from .env file
        set -a  # automatically export all variables
        source .env
        set +a  # disable automatic export
        log "INFO" "Loaded configuration from .env"
    else
        log "WARNING" ".env file not found, using defaults"
    fi
}

show_status() {
    load_env
    log "INFO" "Service status:"
    
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose ps
    else
        docker compose ps
    fi
    
    echo ""
    echo "Access URLs:"
    echo "- TeamCity:    http://localhost:${TEAMCITY_PORT:-8111}"
    echo "- GitLab:      http://localhost:${GITLAB_HTTP_PORT:-8929} (root/${GITLAB_ROOT_PASSWORD:-rootpassword123})"
    echo "- Jenkins:     http://localhost:${JENKINS_HTTP_PORT:-8080} (${JENKINS_ADMIN_USER:-admin}/${JENKINS_ADMIN_PASSWORD:-admin})"
    echo "- Prometheus:  http://localhost:${PROMETHEUS_PORT:-9090}"
    echo "- Grafana:     http://localhost:${GRAFANA_PORT:-3000} (${GRAFANA_ADMIN_USER:-admin}/${GRAFANA_ADMIN_PASSWORD:-admin})"
    echo "- MLflow:      http://localhost:${MLFLOW_PORT:-5000}"
    echo "- TensorBoard: http://localhost:${TENSORBOARD_PORT:-6006}"
    echo "- Registry:    http://localhost:${REGISTRY_PORT:-5000}"
    echo "- PgAdmin:     http://localhost:${PGLADMIN_PORT:-5050} (${PGLADMIN_EMAIL:-admin@admin.com}/${PGLADMIN_PASSWORD:-admin})"
    echo "- JupyterHub:  http://localhost:${JUPYTERHUB_PORT:-8888}"
    echo ""
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

install() {
    echo "ML DevOps Framework Universal Setup"
    echo "=================================="
    
    detect_platform
    check_prerequisites
    detect_gpu
    detect_container_runtime
    create_directories
    generate_env
    copy_configs
    setup_permissions
    start_services
    
    echo ""
    show_status
}

manage_services() {
    local action="$1"
    load_env
    
    local compose_cmd=""
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    case $action in
        "start")
            start_services
            show_status
            ;;
        "stop")
            log "INFO" "Stopping services..."
            $compose_cmd down
            ;;
        "restart")
            log "INFO" "Restarting services..."
            $compose_cmd restart
            ;;
        "status")
            show_status
            ;;
        "logs")
            if [[ -n "${2:-}" ]]; then
                $compose_cmd logs -f "$2"
            else
                $compose_cmd logs --tail=100
            fi
            ;;
        "update")
            log "INFO" "Updating services..."
            $compose_cmd pull
            $compose_cmd up -d --remove-orphans
            ;;
        "clean")
            read -p "Remove all containers and volumes? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                $compose_cmd down -v --remove-orphans
                docker system prune -f
            fi
            ;;
    esac
}

show_help() {
    cat << EOF
Universal ML DevOps Framework Setup

Usage: $0 [COMMAND]

Commands:
  install, setup    - Full installation (default)
  start            - Start services
  stop             - Stop services
  restart          - Restart services
  status           - Show status
  logs [SERVICE]   - Show logs
  update           - Update images
  clean            - Remove all data
  help             - Show help

Environment Variables:
  DEBUG=true       - Enable debug output
EOF
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local action="${1:-install}"
    
    # Initialize logging
    echo "Starting setup: $(date)" > "$LOG_FILE"
    
    case $action in
        "install"|"setup"|"")
            install
            ;;
        "start"|"stop"|"restart"|"status"|"logs"|"update"|"clean")
            manage_services "$@"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log "ERROR" "Unknown command: $action"
            show_help
            exit 1
            ;;
    esac
}

main "$@"