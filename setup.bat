@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo.
echo ML DevOps Framework Setup
echo =========================
echo.

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=install"

if /i "%ACTION%"=="start" goto :START
if /i "%ACTION%"=="stop" goto :STOP
if /i "%ACTION%"=="status" goto :STATUS
if /i "%ACTION%"=="install" goto :INSTALL
if /i "%ACTION%"=="help" goto :HELP
goto :HELP

:START
echo Starting services...
if not exist ".env" (
    echo ERROR: .env file not found!
    echo Please copy .env.example to .env and configure your settings.
    exit /b 1
)

echo Checking Docker...
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker Desktop is not running!
    echo Please start Docker Desktop and try again.
    exit /b 1
)

echo Docker is running.

docker compose version >nul 2>&1
if not errorlevel 1 (
    set "COMPOSE=docker compose"
) else (
    set "COMPOSE=docker-compose"
)

echo.
echo Starting core services...
%COMPOSE% up -d postgres redis

echo.
echo Waiting for database...
timeout /t 10 /nobreak >nul

echo.
echo Starting application services...
%COMPOSE% up -d gitlab jenkins prometheus grafana mlflow

echo.
echo Starting remaining services...
%COMPOSE% up -d tensorboard node-exporter postgres-exporter redis-exporter

echo.
echo Configuring GitLab root user...
timeout /t 10 /nobreak >nul

REM Load GITLAB_ROOT_PASSWORD from .env
for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
    if "%%a"=="GITLAB_ROOT_PASSWORD" set "GITLAB_ROOT_PASSWORD=%%b"
)

if not defined GITLAB_ROOT_PASSWORD set "GITLAB_ROOT_PASSWORD=rootpassword123"

for /L %%i in (1,1,30) do (
    docker exec gitlab gitlab-rails runner "User.find_by(username: 'root')" >nul 2>&1
    if not errorlevel 1 (
        echo GitLab root user already exists.
        goto :GITLAB_CONFIGURED
    )
    
    docker exec gitlab gitlab-rails runner "user = User.new(username: 'root', email: 'admin@example.com', name: 'Administrator', admin: true, password: '%GITLAB_ROOT_PASSWORD%', password_confirmation: '%GITLAB_ROOT_PASSWORD%'); user.skip_confirmation!; user.save!(validate: false); puts 'Root user created'" >nul 2>&1
    if not errorlevel 1 (
        echo GitLab root user created successfully!
        goto :GITLAB_CONFIGURED
    )
    
    timeout /t 10 /nobreak >nul
)

echo WARNING: Could not configure GitLab root user automatically.

:GITLAB_CONFIGURED
echo.
echo Services started!
echo.
%COMPOSE% ps
goto :END

:STOP
docker compose version >nul 2>&1
if not errorlevel 1 (
    docker compose down
) else (
    docker-compose down
)
goto :END

:STATUS
docker compose version >nul 2>&1
if not errorlevel 1 (
    docker compose ps
) else (
    docker-compose ps
)
echo.
echo Access URLs:
echo - Jenkins:     http://localhost:8080
echo - GitLab:      http://localhost:8929
echo - Prometheus:  http://localhost:9090
echo - Grafana:     http://localhost:3000
echo - MLflow:      http://localhost:5000
goto :END

:INSTALL
echo Installing...
if not exist ".env" (
    echo ERROR: .env file not found!
    echo Please copy .env.example to .env
    exit /b 1
)

if not exist "logs" mkdir "logs"

echo Environment ready.
echo Run: setup.bat start
goto :END

:HELP
echo Usage: %~nx0 [COMMAND]
echo.
echo Commands:
echo   start    - Start all services
echo   stop     - Stop all services
echo   status   - Show service status
echo   install  - Check prerequisites
echo   help     - Show this help
echo.
goto :END

:END
endlocal
