@echo off
REM =============================================================================
REM ML DevOps Framework Setup - Windows Batch Script
REM Universal ML DevOps Framework Configuration for Windows
REM =============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%SCRIPT_DIR%setup.log"
set "PLATFORM=windows"
set "ARCHITECTURE="
set "CONTAINER_RUNTIME="
set "GPU_AVAILABLE=false"

REM =============================================================================
REM UTILITY FUNCTIONS
REM =============================================================================

:log
    set "level=%~1"
    set "message=%~2"
    for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set "mydate=%%c-%%a-%%b"
    for /f "tokens=1-2 delims=: " %%a in ('time /t') do set "mytime=%%a:%%b"
    
    if "%level%"=="INFO" echo [INFO] %message%
    if "%level%"=="SUCCESS" echo [SUCCESS] %message%
    if "%level%"=="WARNING" echo [WARNING] %message%
    if "%level%"=="ERROR" echo [ERROR] %message%
    
    echo [%mydate% %mytime%] [%level%] %message% >> "%LOG_FILE%"
    goto :eof

:detect_platform
    call :log "INFO" "Detecting platform..."
    
    REM Detect architecture
    if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCHITECTURE=amd64"
    if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCHITECTURE=arm64"
    if "%PROCESSOR_ARCHITECTURE%"=="x86" set "ARCHITECTURE=x86"
    
    call :log "SUCCESS" "Platform: %PLATFORM%, Architecture: %ARCHITECTURE%"
    goto :eof



:detect_gpu
    call :log "INFO" "Detecting GPU..."
    
    where nvidia-smi >nul 2>&1
    if not errorlevel 1 (
        nvidia-smi >nul 2>&1
        if not errorlevel 1 (
            set "GPU_AVAILABLE=true"
            call :log "SUCCESS" "NVIDIA GPU detected"
        )
    )
    goto :eof

:detect_container_runtime
    call :log "INFO" "Detecting container runtime..."
    
    where docker >nul 2>&1
    if not errorlevel 1 (
        set "CONTAINER_RUNTIME=docker"
        docker info >nul 2>&1
        if not errorlevel 1 (
            call :log "SUCCESS" "Docker is running"
        ) else (
            call :log "WARNING" "Docker not running"
        )
    )
    goto :eof

:create_directories
    call :log "INFO" "Creating necessary directories..."
    
    if not exist "logs" mkdir "logs"
    
    call :log "SUCCESS" "Directories ready"
    goto :eof

:check_env
    call :log "INFO" "Checking environment configuration..."
    
    if not exist ".env" (
        call :log "ERROR" ".env file not found!"
        call :log "ERROR" "Please copy .env.example to .env and configure your settings."
        exit /b 1
    )
    
    call :log "SUCCESS" "Environment file found"
    goto :eof

:start_services
    call :log "INFO" "Starting services..."
    
    docker info >nul 2>&1
    if errorlevel 1 (
        call :log "ERROR" "Docker not running"
        exit /b 1
    )
    
    REM Determine compose command
    docker compose version >nul 2>&1
    if not errorlevel 1 (
        set "compose_cmd=docker compose"
    ) else (
        where docker-compose >nul 2>&1
        if not errorlevel 1 (
            set "compose_cmd=docker-compose"
        ) else (
            call :log "ERROR" "No compose command found"
            exit /b 1
        )
    )
    
    call :log "INFO" "Using compose command: !compose_cmd!"
    
    REM Start core services
    call :log "INFO" "Starting core services..."
    !compose_cmd! up -d postgres redis
    if errorlevel 1 (
        call :log "ERROR" "Failed to start core services"
        !compose_cmd! logs postgres
        exit /b 1
    )
    
    REM Wait for database
    call :log "INFO" "Waiting for database..."
    set /a attempts=0
    set /a max_attempts=60
    set "postgres_ready=false"
    
    :wait_postgres
    if !attempts! geq !max_attempts! goto :postgres_timeout
    
    docker exec postgres-db pg_isready -U postgres >nul 2>&1
    if not errorlevel 1 (
        call :log "SUCCESS" "Database is ready"
        set "postgres_ready=true"
        goto :postgres_ready
    )
    
    set /a attempts+=1
    if !attempts! equ 10 call :log "INFO" "Still waiting for database... (!attempts!/!max_attempts!)"
    if !attempts! equ 20 call :log "INFO" "Still waiting for database... (!attempts!/!max_attempts!)"
    if !attempts! equ 30 call :log "INFO" "Still waiting for database... (!attempts!/!max_attempts!)"
    if !attempts! equ 40 call :log "INFO" "Still waiting for database... (!attempts!/!max_attempts!)"
    if !attempts! equ 50 call :log "INFO" "Still waiting for database... (!attempts!/!max_attempts!)"
    
    timeout /t 5 /nobreak >nul
    goto :wait_postgres
    
    :postgres_timeout
    call :log "ERROR" "Database failed to start within 300 seconds"
    !compose_cmd! ps
    !compose_cmd! logs postgres
    exit /b 1
    
    :postgres_ready
    REM Start application services
    call :log "INFO" "Starting application services..."
    !compose_cmd! up -d gitlab jenkins prometheus grafana mlflow
    if errorlevel 1 (
        call :log "WARNING" "Some application services failed to start"
        !compose_cmd! ps
    )
    
    REM Start remaining services
    call :log "INFO" "Starting remaining services..."
    !compose_cmd! up -d tensorboard node-exporter
    
    REM Start GPU services if available
    if "%GPU_AVAILABLE%"=="true" (
        !compose_cmd! up -d gpu-exporter 2>nul
        if errorlevel 1 call :log "WARNING" "GPU services not available"
    )
    
    call :log "SUCCESS" "Services started"
    
    REM Show final status
    call :log "INFO" "Final service status:"
    !compose_cmd! ps
    goto :eof

:show_status
    call :log "INFO" "Service status:"
    
    docker compose version >nul 2>&1
    if not errorlevel 1 (
        docker compose ps
    ) else (
        docker-compose ps
    )
    
    echo.
    echo Access URLs:
    echo - Jenkins:     http://localhost:8080 (admin/admin)
    echo - GitLab:      http://localhost:8929 (root/rootpassword123)
    echo - Prometheus:  http://localhost:9090
    echo - Grafana:     http://localhost:3000 (admin/admin)
    echo - MLflow:      http://localhost:5000
    echo - TensorBoard: http://localhost:6006
    echo - Registry:    http://localhost:5000
    echo - PgAdmin:     http://localhost:5050 (admin@admin.com/admin)
    echo - JupyterHub:  http://localhost:8888
    echo.
    goto :eof

:install
    echo ML DevOps Framework Setup (Windows)
    echo ====================================
    echo.
    
    call :detect_platform
    call :check_env
    call :detect_gpu
    call :detect_container_runtime
    call :create_directories
    call :start_services
    
    echo.
    call :show_status
    goto :eof

:manage_services
    set "action=%~1"
    
    docker compose version >nul 2>&1
    if not errorlevel 1 (
        set "compose_cmd=docker compose"
    ) else (
        set "compose_cmd=docker-compose"
    )
    
    if "%action%"=="start" (
        call :start_services
        call :show_status
    )
    
    if "%action%"=="stop" (
        call :log "INFO" "Stopping services..."
        !compose_cmd! down
    )
    
    if "%action%"=="restart" (
        call :log "INFO" "Restarting services..."
        !compose_cmd! restart
    )
    
    if "%action%"=="status" (
        call :show_status
    )
    
    if "%action%"=="logs" (
        if not "%~2"=="" (
            !compose_cmd! logs -f %~2
        ) else (
            !compose_cmd! logs --tail=100
        )
    )
    
    if "%action%"=="update" (
        call :log "INFO" "Updating services..."
        !compose_cmd! pull
        !compose_cmd! up -d --remove-orphans
    )
    
    if "%action%"=="clean" (
        set /p confirm="Remove all containers and volumes? (y/N): "
        if /i "!confirm!"=="y" (
            !compose_cmd! down -v --remove-orphans
            docker system prune -f
        )
    )
    goto :eof

:show_help
    echo Universal ML DevOps Framework Setup
    echo.
    echo Usage: %~nx0 [COMMAND]
    echo.
    echo Commands:
    echo   install, setup    - Full installation (default)
    echo   start            - Start services
    echo   stop             - Stop services
    echo   restart          - Restart services
    echo   status           - Show status
    echo   logs [SERVICE]   - Show logs
    echo   update           - Update images
    echo   clean            - Remove all data
    echo   help             - Show help
    echo.
    goto :eof

REM =============================================================================
REM MAIN EXECUTION
REM =============================================================================

:main
    echo Starting setup: %date% %time% > "%LOG_FILE%"
    
    set "action=%~1"
    if "%action%"=="" set "action=install"
    
    if "%action%"=="install" goto :install
    if "%action%"=="setup" goto :install
    if "%action%"=="start" goto :manage_start
    if "%action%"=="stop" goto :manage_stop
    if "%action%"=="restart" goto :manage_restart
    if "%action%"=="status" goto :manage_status
    if "%action%"=="logs" goto :manage_logs
    if "%action%"=="update" goto :manage_update
    if "%action%"=="clean" goto :manage_clean
    if "%action%"=="help" goto :show_help
    if "%action%"=="-h" goto :show_help
    if "%action%"=="--help" goto :show_help
    
    call :log "ERROR" "Unknown command: %action%"
    call :show_help
    exit /b 1

:manage_start
    call :manage_services "start"
    goto :end

:manage_stop
    call :manage_services "stop"
    goto :end

:manage_restart
    call :manage_services "restart"
    goto :end

:manage_status
    call :manage_services "status"
    goto :end

:manage_logs
    call :manage_services "logs" "%~2"
    goto :end

:manage_update
    call :manage_services "update"
    goto :end

:manage_clean
    call :manage_services "clean"
    goto :end

:end
    endlocal
    exit /b 0

REM Run main
call :main %*
