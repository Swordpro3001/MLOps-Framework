# ML DevOps Framework - Universelle Dokumentation

## Übersicht

Das ML DevOps Framework ist eine plattformübergreifende Lösung für Machine Learning DevOps, die auf Docker Compose basiert und sowohl auf Linux als auch Windows (WSL/Git Bash) funktioniert. Es bietet eine vollständige CI/CD-Pipeline mit Monitoring, ML-Experiment-Tracking und GPU-Unterstützung.

## Inhaltsverzeichnis

1. [Architektur](#architektur)
2. [Docker Compose Konfiguration](#docker-compose-konfiguration)
3. [Setup Script](#setup-script)
4. [Services im Detail](#services-im-detail)
5. [Plattform-spezifische Konfigurationen](#plattform-spezifische-konfigurationen)
6. [Monitoring und Logging](#monitoring-und-logging)
7. [GPU-Unterstützung](#gpu-unterstützung)
8. [Verwendung](#verwendung)
9. [Troubleshooting](#troubleshooting)

## Architektur

### Netzwerk-Architektur

Das Framework verwendet ein einziges Docker-Netzwerk (`devops-network`) mit dem Subnetz `172.20.0.0/16`:

```
┌─────────────────────────────────────────────────────────────┐
│                    devops-network                           │
│                  172.20.0.0/16                              │
├─────────────────────────────────────────────────────────────┤
│    Core Infrastructure  │  CI Services  │  CD Services      │
│     ┌─────────────┐     │  ┌─────────┐  │  ┌─────────────┐  │
│     │ PostgreSQL  │     │  │TeamCity │  │  │   Jenkins   │  │
│     │   :5432     │     │  │  :8111  │  │  │   :8080     │  │
│     └─────────────┘     │  └─────────┘  │  └─────────────┘  │
│     ┌─────────────┐     │  ┌─────────┐  │                   │
│     │   Redis     │     │  │ GitLab  │  │                   │
│     │   :6379     │     │  │ :8929   │  │                   │
│     └─────────────┘     │  └─────────┘  │                   │
├─────────────────────────────────────────────────────────────┤
│     ML Services        │  Monitoring    │  Utilities        │
│     ┌─────────────┐    │  ┌──────────┐  │  ┌─────────────┐  │
│     │   MLflow    │    │  │Prometheus│  │  │   Registry  │  │
│     │   :5000     │    │  │  :9090   │  │  │   :5000     │  │
│     └─────────────┘    │  └──────────┘  │  └─────────────┘  │
│     ┌─────────────┐    │  ┌──────────┐  │  ┌─────────────┐  │
│     │TensorBoard  │    │  │ Grafana  │  │  │   PgAdmin   │  │
│     │   :6006     │    │  │  :3000   │  │  │   :5050     │  │
│     └─────────────┘    │  └──────────┘  │  └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Volume-Architektur

Alle persistenten Daten werden in benannten Docker-Volumes gespeichert:

```
volumes/
├── postgres-data/          # PostgreSQL Datenbank
├── teamcity-data/          # TeamCity Server Daten
├── teamcity-logs/          # TeamCity Logs
├── gitlab-config/          # GitLab Konfiguration
├── gitlab-data/            # GitLab Daten
├── jenkins-data/           # Jenkins Konfiguration
├── prometheus-data/        # Prometheus Metriken
├── grafana-data/           # Grafana Dashboards
├── mlflow-artifacts/       # MLflow Modelle und Artefakte
├── registry-data/          # Docker Registry
├── jupyterhub-data/        # JupyterHub Daten
└── redis-data/             # Redis Cache
```

## Docker Compose Konfiguration

### Hauptdatei: `docker-compose.yaml`

Die Hauptkonfiguration ist in `docker-compose.yaml` definiert und enthält alle Services mit plattformübergreifenden Einstellungen.

#### Netzwerk-Konfiguration

```yaml
networks:
  devops-network:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.20.0.0/16
```

#### Service-Kategorien

**1. Core Infrastructure**
- `postgres`: PostgreSQL 14 Datenbank
- `redis`: Redis 7 Cache

**2. CI Services**
- `teamcity-server`: JetBrains TeamCity CI Server
- `teamcity-agent`: TeamCity Build Agent
- `gitlab`: GitLab CE mit Container Registry

**3. CD Services**
- `jenkins`: Jenkins LTS mit JDK 17

**4. ML Services**
- `mlflow`: MLflow Experiment Tracking
- `tensorboard`: TensorBoard für Visualisierung
- `jupyterhub`: JupyterHub für Entwicklung

**5. Monitoring**
- `prometheus`: Metriken-Sammlung
- `grafana`: Visualisierung und Dashboards
- `node-exporter`: System-Metriken
- `gpu-exporter`: GPU-Metriken (optional)

**6. Utilities**
- `registry`: Docker Container Registry
- `pgadmin`: PostgreSQL Administration
- `kubernetes-cluster`: Kind Kubernetes Cluster

### Override-Datei: `docker-compose.override.yml`

Plattform-spezifische Anpassungen werden in `docker-compose.override.yml` definiert:

#### Windows-spezifische Konfigurationen

```yaml
services:
  node-exporter:
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($|/)'
```

### Umgebungsvariablen

Das Framework verwendet eine zentrale `.env`-Datei für alle Konfigurationen:

#### Konfigurationsstruktur

**1. Template-Datei (`.env.template`)**
- Enthält alle verfügbaren Konfigurationsoptionen
- Wird im Repository gespeichert
- Dient als Vorlage für neue Installationen

**2. Aktuelle Konfiguration (`.env`)**
- Wird automatisch vom Setup-Script erstellt
- Enthält plattformspezifische Einstellungen
- Wird in `.gitignore` ausgeschlossen (Sicherheit)

#### Konfigurationskategorien

```bash
# Plattform-Erkennung (automatisch gesetzt)
DETECTED_PLATFORM=linux
DETECTED_ARCHITECTURE=amd64
GPU_AVAILABLE=true
WSL_DETECTED=false

# Service-Ports
POSTGRES_PORT=55432
TEAMCITY_PORT=8111
GITLAB_HTTP_PORT=8929
JENKINS_HTTP_PORT=8080
# ... weitere Ports

# Datenbank-Konfiguration
POSTGRES_ROOT_PASSWORD=rootpass
POSTGRES_DB_TEAMCITY=teamcity
POSTGRES_USER_TEAMCITY=teamcity
# ... weitere DB-User

# Service-Authentifizierung
GITLAB_ROOT_PASSWORD=rootpassword123
JENKINS_ADMIN_USER=admin
JENKINS_ADMIN_PASSWORD=admin
# ... weitere Credentials
```

#### Konfigurationsverwaltung

```bash
# Konfiguration anzeigen
./setup.sh config

# Konfiguration validieren
./setup.sh validate

# Template zurücksetzen
cp .env.template .env
```

## Setup Script

### `setup.sh` - Universelles Setup-Script

Das Setup-Script ist ein Bash-Script, das automatisch die Plattform erkennt und das Framework entsprechend konfiguriert.

#### Hauptfunktionen

**1. Plattform-Erkennung**
```bash
detect_platform() {
    case "$(uname -s)" in
        Linux*) PLATFORM="linux" ;;
        Darwin*) PLATFORM="macos" ;;
        CYGWIN*|MINGW*|MSYS*) PLATFORM="windows" ;;
    esac
}
```

**2. Abhängigkeitsprüfung**
```bash
check_prerequisites() {
    local missing_deps=()
    command -v docker >/dev/null || missing_deps+=("docker")
    command -v git >/dev/null || missing_deps+=("git")
    # ... weitere Checks
}
```

**3. GPU-Erkennung**
```bash
detect_gpu() {
    if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
        GPU_AVAILABLE=true
        log "SUCCESS" "NVIDIA GPU detected"
    fi
}
```

**4. Verzeichnisstruktur erstellen**
```bash
create_directory_structure() {
    local directories=(
        "volumes/postgres/data"
        "volumes/teamcity-server/data"
        "monitoring/grafana/dashboards"
        # ... weitere Verzeichnisse
    )
}
```

**5. Service-Start in Stufen**
```bash
start_services() {
    # Stufe 1: Core Infrastructure
    $compose_cmd up -d postgres redis registry
    
    # Stufe 2: CI Services
    $compose_cmd up -d teamcity-server gitlab
    
    # Stufe 3: CD und Monitoring
    $compose_cmd up -d jenkins prometheus grafana
    
    # Stufe 4: ML Services
    $compose_cmd up -d mlflow tensorboard jupyterhub
    
    # Stufe 5: GPU Services (optional)
    if $GPU_AVAILABLE; then
        $compose_cmd --profile gpu up -d gpu-exporter
    fi
}
```

#### Script-Befehle

```bash
./setup.sh install    # Vollständige Installation (Standard)
./setup.sh start      # Services starten
./setup.sh stop       # Services stoppen
./setup.sh restart    # Services neu starten
./setup.sh status     # Service-Status anzeigen
./setup.sh logs       # Logs anzeigen
./setup.sh update     # Services aktualisieren
./setup.sh config     # Konfiguration anzeigen
./setup.sh validate   # Konfiguration validieren
./setup.sh clean      # Alles löschen
./setup.sh help       # Hilfe anzeigen
```

#### Konfigurationsverwaltung

Das Setup-Script bietet erweiterte Konfigurationsverwaltung:

**Automatische Konfiguration:**
- Erstellt `.env.template` beim ersten Lauf
- Kopiert Template zu `.env` falls nicht vorhanden
- Aktualisiert nur plattformspezifische Variablen
- Behält benutzerdefinierte Einstellungen bei

**Konfigurationsvalidierung:**
- Prüft auf fehlende erforderliche Variablen
- Zeigt aktuelle Konfiguration an
- Warnt bei inkonsistenten Einstellungen

## Services im Detail

### Core Infrastructure

#### PostgreSQL (`postgres`)
- **Image**: `postgres:14`
- **Port**: `55432` (extern) → `5432` (intern)
- **Volumes**: `postgres-data:/var/lib/postgresql/data`
- **Health Check**: `pg_isready -U postgres`
- **Features**:
  - Automatische Datenbank-Initialisierung via `init-db/init.sql`
  - Separate Datenbanken für TeamCity, GitLab und MLflow
  - UTF-8 Encoding mit C Locale

#### Redis (`redis`)
- **Image**: `redis:7-alpine`
- **Port**: `6379`
- **Volumes**: `redis-data:/data`
- **Konfiguration**:
  - AOF (Append Only File) aktiviert
  - Max Memory: 512MB
  - LRU Eviction Policy
  - Passwort-geschützt

### CI Services

#### TeamCity Server (`teamcity-server`)
- **Image**: `jetbrains/teamcity-server:2023.11`
- **Port**: `8111`
- **Memory**: 2GB Heap + 512MB Code Cache
- **Dependencies**: PostgreSQL
- **Features**:
  - Automatische Konfiguration
  - Build-Agent Management
  - Integration mit GitLab

#### TeamCity Agent (`teamcity-agent`)
- **Image**: `jetbrains/teamcity-agent:2023.11`
- **Features**:
  - Docker-in-Docker Support
  - GPU-Unterstützung (NVIDIA)
  - ML-Modelle Zugriff
  - Cross-Platform Builds

#### GitLab (`gitlab`)
- **Image**: `gitlab/gitlab-ce:16.5.1-ce.0`
- **Ports**: `8929` (HTTP), `8443` (HTTPS), `2222` (SSH)
- **Features**:
  - Container Registry integriert
  - CI/CD Pipeline Support
  - PostgreSQL Backend
  - Performance-optimiert für Container

### CD Services

#### Jenkins (`jenkins`)
- **Image**: `jenkins/jenkins:lts-jdk17`
- **Ports**: `8080` (HTTP), `50000` (Agent)
- **Memory**: 2GB Heap
- **Features**:
  - Docker-in-Docker Support
  - ML-Modelle Zugriff
  - GitLab Integration
  - Pipeline-as-Code

### ML Services

#### MLflow (`mlflow`)
- **Image**: `python:3.11-slim`
- **Port**: `5000`
- **Features**:
  - PostgreSQL Backend
  - Artifact Storage
  - Model Registry
  - Multi-Worker Support
  - Automatische DB-Migration

#### TensorBoard (`tensorboard`)
- **Image**: `tensorflow/tensorflow:2.14.0`
- **Port**: `6006`
- **Features**:
  - GPU-Unterstützung
  - Live-Reload
  - Model-Visualisierung

#### JupyterHub (`jupyterhub`)
- **Image**: `quay.io/jupyterhub/jupyterhub:4.0.2`
- **Port**: `8888`
- **Features**:
  - Docker Spawner
  - GPU-Unterstützung
  - Shared Model Directory
  - Multi-User Support

### Monitoring

#### Prometheus (`prometheus`)
- **Image**: `prom/prometheus:v2.47.2`
- **Port**: `9090`
- **Features**:
  - 15 Tage Retention
  - Service Discovery
  - Alert Rules
  - Grafana Integration

#### Grafana (`grafana`)
- **Image**: `grafana/grafana:10.2.0`
- **Port**: `3000`
- **Features**:
  - Pre-configured Dashboards
  - Prometheus Data Source
  - Plugin Support
  - User Management

#### Node Exporter (`node-exporter`)
- **Image**: `prom/node-exporter:v1.6.1`
- **Port**: `9100`
- **Features**:
  - System Metrics
  - Cross-Platform Support
  - File System Monitoring

### Utilities

#### Docker Registry (`registry`)
- **Image**: `registry:2.8.3`
- **Port**: `5000`
- **Features**:
  - Private Container Registry
  - Delete Support
  - Authentication Ready

#### PgAdmin (`pgadmin`)
- **Image**: `dpage/pgadmin4:7.8`
- **Port**: `5050`
- **Features**:
  - Web-basierte PostgreSQL Administration
  - Multi-Database Support
  - Query Editor

## Plattform-spezifische Konfigurationen

### Linux
- Native Docker Socket Mounting
- System Metrics via `/proc` und `/sys`
- GPU Support via NVIDIA Container Toolkit
- Systemd Service Integration

### Windows (WSL/Git Bash)
- Docker Desktop Integration
- WSL2 Backend Support
- Windows-spezifische Pfad-Anpassungen
- PowerShell Integration

### macOS
- Docker Desktop für macOS
- Metal GPU Support
- Homebrew Integration
- macOS-spezifische Pfade

## Monitoring und Logging

### Prometheus Konfiguration

Die Prometheus-Konfiguration (`monitoring/prometheus-universal.yml`) sammelt Metriken von:

- **System**: CPU, Memory, Disk, Network
- **Services**: Jenkins, GitLab, TeamCity, MLflow
- **Databases**: PostgreSQL, Redis
- **GPU**: NVIDIA GPU Metriken (falls verfügbar)

### Grafana Dashboards

Vordefinierte Dashboards für:
- System Overview
- Service Health
- ML Experiment Tracking
- GPU Utilization
- CI/CD Pipeline Status

### Logging

- **Zentralisiert**: Alle Container-Logs via Docker
- **Strukturiert**: JSON-Format für bessere Analyse
- **Rotierend**: Automatische Log-Rotation
- **Plattform-übergreifend**: Einheitliche Log-Struktur

## GPU-Unterstützung

### Automatische Erkennung

Das Framework erkennt automatisch verfügbare GPUs:

```bash
# NVIDIA GPU
if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
    GPU_AVAILABLE=true
fi

# AMD ROCm
if command -v rocm-smi >/dev/null 2>&1; then
    GPU_AVAILABLE=true
fi
```

### GPU-Services

- **TensorBoard**: Automatische GPU-Nutzung
- **JupyterHub**: GPU-fähige Notebooks
- **TeamCity Agent**: GPU-Builds
- **GPU Exporter**: Metriken-Sammlung

### Docker GPU Support

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

## Verwendung

### Schnellstart

```bash
# 1. Repository klonen
git clone <repository-url>
cd ml-devops

# 2. Setup ausführen
./setup.sh

# 3. Services überwachen
./setup.sh status
```

### Service-Zugriff

Nach dem Setup sind folgende Services verfügbar:

| Service | URL | Credentials |
|---------|-----|-------------|
| TeamCity | http://localhost:8111 | Setup beim ersten Start |
| GitLab | http://localhost:8929 | root/rootpassword123 |
| Jenkins | http://localhost:8080 | admin/admin |
| Grafana | http://localhost:3000 | admin/admin |
| MLflow | http://localhost:5000 | - |
| TensorBoard | http://localhost:6006 | - |
| JupyterHub | http://localhost:8888 | - |
| PgAdmin | http://localhost:5050 | admin@admin.com/admin |

### ML Training Test

```bash
# In das ML-Modelle Verzeichnis wechseln
cd ml-models

# Universelles Training-Script ausführen
python universal_train.py
```

### Service-Management

```bash
# Services starten
./setup.sh start

# Services stoppen
./setup.sh stop

# Services neu starten
./setup.sh restart

# Service-Status prüfen
./setup.sh status

# Logs anzeigen
./setup.sh logs
./setup.sh logs jenkins  # Spezifischer Service

# Services aktualisieren
./setup.sh update

# Alles löschen (Vorsicht!)
./setup.sh clean
```

## Troubleshooting

### Häufige Probleme

#### 1. Docker nicht verfügbar
```bash
# Linux
sudo systemctl start docker

# Windows
# Docker Desktop starten

# macOS
# Docker Desktop starten
```

#### 2. Port-Konflikte
```bash
# Verfügbare Ports prüfen
netstat -tulpn | grep :8080

# Ports in .env anpassen
nano .env
```

#### 3. GPU nicht erkannt
```bash
# NVIDIA Treiber prüfen
nvidia-smi

# Docker GPU Support testen
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi
```

#### 4. Services starten nicht
```bash
# Logs prüfen
./setup.sh logs

# Einzelne Services starten
docker-compose up -d postgres
docker-compose up -d redis
```

#### 5. Speicher-Probleme
```bash
# Docker System bereinigen
docker system prune -f

# Volumes prüfen
docker volume ls
docker volume rm <volume-name>
```

### Debug-Modus

```bash
# Debug-Output aktivieren
DEBUG=true ./setup.sh

# Detaillierte Logs
./setup.sh logs | grep ERROR
```

### Performance-Optimierung

#### Speicher-Anpassungen

```bash
# In .env anpassen
POSTGRES_SHARED_BUFFERS=256MB
JENKINS_JAVA_OPTS=-Xmx2g -Xms512m
GITLAB_MEMORY_LIMIT=4g
```

#### Service-Profiling

```bash
# Ressourcen-Verbrauch prüfen
docker stats

# Spezifische Service-Metriken
docker exec prometheus wget -qO- http://localhost:9090/api/v1/query?query=container_memory_usage_bytes
```

## Erweiterte Konfiguration

### Custom Services hinzufügen

1. Service in `docker-compose.yaml` definieren
2. Volume-Mapping in `volumes/` erstellen
3. Monitoring-Konfiguration in Prometheus hinzufügen
4. Setup-Script erweitern

### Externe Datenbanken

```yaml
# In docker-compose.yaml
services:
  postgres:
    external: true
    # ... Konfiguration anpassen
```

### SSL/TLS Konfiguration

```yaml
# Zertifikate in certs/ ablegen
volumes:
  - ./certs:/certs:ro
environment:
  - SSL_CERT_FILE=/certs/cert.pem
  - SSL_KEY_FILE=/certs/key.pem
```

## Sicherheit

### Standard-Sicherheitsmaßnahmen

- Alle Services mit Passwörtern geschützt
- Netzwerk-Isolation via Docker Networks
- Volume-Isolation
- Keine Root-Rechte in Containern

### Produktions-Hardening

1. **Passwörter ändern**: Alle Standard-Passwörter in `.env` anpassen
2. **SSL/TLS**: Zertifikate für HTTPS-Services
3. **Firewall**: Nur notwendige Ports öffnen
4. **Updates**: Regelmäßige Image-Updates
5. **Backups**: Automatische Volume-Backups

## Support und Wartung

### Regelmäßige Wartung

```bash
# Wöchentlich: Services aktualisieren
./setup.sh update

# Monatlich: System bereinigen
docker system prune -f

# Bei Problemen: Logs prüfen
./setup.sh logs | grep -i error
```

### Monitoring

- **Grafana Dashboards**: Service-Health überwachen
- **Prometheus Alerts**: Automatische Benachrichtigungen
- **Log-Aggregation**: Zentrale Log-Sammlung

### Backup-Strategie

```bash
# Volume-Backup
docker run --rm -v postgres-data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz -C /data .

# Konfiguration-Backup
tar czf config-backup.tar.gz docker-compose.yaml .env monitoring/
```

---

## Optimierungen und Best Practices

### Zentralisierte Konfiguration

Das Framework wurde optimiert, um Redundanzen zu vermeiden:

**Vorher:**
- Konfiguration sowohl in `setup.sh` als auch in `.env`
- Duplikation von Einstellungen
- Schwierige Wartung bei Änderungen

**Nachher:**
- Zentrale `.env.template` als einzige Quelle der Wahrheit
- Setup-Script aktualisiert nur plattformspezifische Variablen
- Benutzerdefinierte Einstellungen bleiben erhalten
- Einfache Wartung und Erweiterung

### Konfigurationsverwaltung

```bash
# 1. Template erstellen (automatisch beim ersten Lauf)
./setup.sh install

# 2. Konfiguration anpassen
nano .env

# 3. Konfiguration validieren
./setup.sh validate

# 4. Aktuelle Einstellungen anzeigen
./setup.sh config

# 5. Template zurücksetzen (falls nötig)
cp .env.template .env
```

### Sicherheitsaspekte

- `.env`-Datei ist in `.gitignore` ausgeschlossen
- `.env.template` enthält keine sensiblen Daten
- Plattformspezifische Einstellungen werden automatisch gesetzt
- Benutzer können sichere Passwörter in `.env` setzen

## Fazit

Das ML DevOps Framework bietet eine vollständige, plattformübergreifende Lösung für Machine Learning DevOps. Mit automatischer Plattform-Erkennung, umfassendem Monitoring und GPU-Unterstützung ist es sowohl für Entwicklung als auch für Produktion geeignet.

Die modulare Architektur ermöglicht einfache Erweiterungen und Anpassungen, während das universelle Setup-Script die Komplexität der Konfiguration abstrahiert. Die zentralisierte Konfigurationsverwaltung eliminiert Redundanzen und macht das Framework wartungsfreundlicher.
