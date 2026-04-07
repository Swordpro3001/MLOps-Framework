# AI4Ads — MLOps Framework

> Automated deployment and scaling infrastructure for the AI4Ads traffic
> anomaly correction pipeline.  
> Diploma thesis project — TGM 5BHIT 2025/26  
> Partner: R+C Plakatforschung GmbH

---

## Overview

This repository contains the MLOps infrastructure component of the AI4Ads
diploma thesis. The project automates the detection and correction of
flow-conservation violations in traffic frequency data collected by
R+C Plakatforschung GmbH across the Austrian road network.

The MLOps component provides:

- A **13-service Docker Compose topology** for local development and integration
  testing, spanning CI/CD, ML experiment tracking, monitoring, and utilities.
- A **six-stage Jenkins CI/CD pipeline** automating source validation, testing,
  Docker image builds, model training, evaluation, and deployment.
- A **Kubernetes-based serving layer** using KServe for versioned model rollouts
  and canary deployments.
- **Continuous monitoring** via Prometheus and Grafana with three pre-provisioned
  dashboards specific to the traffic-correction pipeline.

---

## Team

| Name | Role | PDCA Phase |
|------|------|-----------|
| Felix Schmid | Data Engineering — GeoPackage ingestion, graph construction | Plan |
| Maya Marr | Data Science — Anomaly detection | Do |
| Benjamin Popescu | Data Science — Anomaly correction | Do |
| Franz Puerto | MLOps / Team Lead — CI/CD, containerisation, model serving, monitoring | Check / Act |

---

## Prerequisites

| Tool | Minimum version |
|------|----------------|
| Docker Engine | 24.0 |
| Docker Compose | v2.20 |
| `kubectl` | 1.28 |
| Python | 3.11 |
| Git | 2.40 |

---

## Quick Start

```bash
# 1. Clone the repository
git clone http://localhost:8929/root/ai4ads.git
cd ai4ads

# 2. Create the environment file
cp .env.example .env
# Edit .env and replace placeholder passwords before proceeding.

# 3. Start the full stack (Linux)
./setup.sh

# Or on Windows Server (Git Bash / PowerShell)
./setup.bat start
```

The setup script starts services in dependency order and prints access URLs on
completion. Allow approximately five minutes for GitLab to complete its
first-run initialisation.

---

## Service Topology

All 13 services run on the `devops-network` bridge (`172.20.0.0/16`).

```
devops-network (172.20.0.0/16)
│
├── Core Infrastructure
│   postgres:5432      redis:6379
│
├── CI/CD
│   gitlab:8929        jenkins:8080
│
├── ML Services
│   mlflow:5000        tensorboard:6006       jupyterhub:8888
│
├── Monitoring
│   prometheus:9090    grafana:3000           node-exporter:9100
│
└── Utilities
    registry:5555      pgadmin:5050           kubernetes-cluster:6443
```

Support services (not in diagram): `postgres-exporter`, `redis-exporter`,
`gpu-exporter`, `pushgateway`.

### Access URLs (default ports)

| Service | URL | Credentials |
|---------|-----|-------------|
| GitLab | http://localhost:8929 | `root` / `GITLAB_ROOT_PASSWORD` |
| Jenkins | http://localhost:8080/jenkins | `admin` / `JENKINS_ADMIN_PASSWORD` |
| MLflow | http://localhost:5000 | — |
| Grafana | http://localhost:3000 | `admin` / `GRAFANA_ADMIN_PASSWORD` |
| Prometheus | http://localhost:9090 | — |
| JupyterHub | http://localhost:8888 | `admin` |
| PgAdmin | http://localhost:5050 | `PGADMIN_EMAIL` / `PGADMIN_PASSWORD` |
| TensorBoard | http://localhost:6006 | — |
| Registry | http://localhost:5555 | — |
| Pushgateway | http://localhost:9091 | — |

---

## Repository Structure

```
ai4ads/
├── docker/
│   ├── Dockerfile.ingestion   # GeoPackage → PostgreSQL loader
│   ├── Dockerfile.trainer     # Model training container
│   └── Dockerfile.api         # Inference API (KServe / FastAPI)
├── docs/
│   └── setup/
│       ├── gitlab-ui-setup.md         # GitLab web UI configuration
│       ├── jenkins-ui-setup.md        # Jenkins plugin and job setup
│       ├── mlflow-ui-setup.md         # MLflow experiment and registry
│       ├── grafana-ui-setup.md        # Dashboard verification
│       ├── kubernetes-kserve-setup.md # Cluster and KServe deployment
│       └── qgis-export-procedure.md   # GeoPackage export (R+C team)
├── init-db/
│   └── init.sql               # PostgreSQL schema initialisation
├── k8s-manifests/
│   ├── namespaces-and-secrets.yaml    # Namespaces, Secrets, ConfigMaps, PVC
│   ├── training-job.yaml              # Kubernetes Job for model training
│   ├── inference-service.yaml         # KServe InferenceService (stable)
│   └── inference-service-canary.yaml  # KServe canary traffic split
├── monitoring/
│   ├── prometheus-universal.yml       # Prometheus scrape configuration
│   ├── rules/
│   │   └── alerts.yml                 # Alert rules (infra + ML pipeline)
│   └── grafana/
│       ├── provisioning/
│       │   ├── datasources/           # Prometheus datasource
│       │   └── dashboards/            # Dashboard loader configuration
│       └── dashboards/
│           ├── infrastructure-health.json
│           ├── ml-pipeline.json
│           └── traffic-data-quality.json
├── src/
│   ├── ingestion/             # GeoPackage ingestion module
│   ├── trainer/               # Model training module
│   ├── api/                   # FastAPI inference application
│   ├── shared/                # Shared utilities (logging, config)
│   └── tests/                 # pytest test suite (≥80 % coverage required)
├── volumes/
│   └── pgadmin/
│       └── servers.json       # PgAdmin server auto-configuration
├── .env.example               # Environment variable template
├── .gitignore
├── docker-compose.yaml        # Full service topology
├── Jenkinsfile                # Six-stage CI/CD pipeline definition
├── requirements-ingestion.txt
├── requirements-train.txt
├── requirements-api.txt
├── setup.sh                   # Linux setup and service management
└── setup.bat                  # Windows Server setup
```

---

## CI/CD Pipeline

The Jenkinsfile defines six sequential stages. Stages 1–3 run on every branch
push; stages 4–6 run only on `main`.

| Stage | Name | Runs on | Description |
|-------|------|---------|-------------|
| 1 | Checkout | all branches | `pip-compile` dependency validation |
| 2 | Test | all branches | ruff, mypy, pytest (≥80 % coverage) |
| 3 | Build & Push | all branches | Multi-stage Docker builds → private registry |
| 4 | Train | `main` only | Kubernetes Job, MLflow tracking |
| 5 | Evaluate | `main` only | Accuracy gate (≥0.75), model promotion |
| 6 | Deploy | `main` only | ConfigMap patch, rolling restart |

### Image Tagging Convention

```
localhost:5555/traffic-<service>:<semver>-<short-sha>

Examples:
  localhost:5555/traffic-trainer:1.2.0-a3f7c9d
  localhost:5555/traffic-api:1.2.0-a3f7c9d
  localhost:5555/traffic-ingestion:1.2.0-a3f7c9d
```

---

## Kubernetes Deployment

Apply all manifests once to bootstrap the cluster:

```bash
# Export kubeconfig from the kind container
docker cp k8s-cluster:/etc/kubernetes/admin.conf ~/.kube/config-ai4ads
export KUBECONFIG=~/.kube/config-ai4ads

# Create namespaces, secrets, ConfigMaps, and PVC
kubectl apply -f k8s-manifests/namespaces-and-secrets.yaml

# Install KServe (requires cert-manager)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
kubectl apply -f https://github.com/kserve/kserve/releases/latest/download/kserve.yaml

# Deploy the InferenceService (after first successful training run)
kubectl apply -f k8s-manifests/inference-service.yaml
```

---

## Monitoring

Three Grafana dashboards are auto-provisioned on first startup:

| Dashboard | UID | Contents |
|-----------|-----|----------|
| Infrastructure Health | `infra-health` | CPU, memory, disk, service uptime |
| ML Pipeline | `ml-pipeline` | Training accuracy, loss curves, Jenkins builds |
| Traffic Data Quality | `traffic-quality` | Flow-conservation violations, correction rate, latency |

Alert rules fire for: service downtime, high resource utilisation, failed
training jobs, model accuracy below 0.75, and inference latency above 2 s.

---

## Setup Guides (UI-Only Steps)

Steps that cannot be scripted and must be performed through the web interface
are documented in `docs/setup/`:

- [`gitlab-ui-setup.md`](docs/setup/gitlab-ui-setup.md) — project creation,
  branch protection, webhook, CI/CD variables, team members.
- [`jenkins-ui-setup.md`](docs/setup/jenkins-ui-setup.md) — plugin
  installation, GitLab connection, credentials, pipeline job, Kubernetes cloud.
- [`mlflow-ui-setup.md`](docs/setup/mlflow-ui-setup.md) — experiment creation,
  model registration, version promotion.
- [`grafana-ui-setup.md`](docs/setup/grafana-ui-setup.md) — provisioning
  verification, alert contact points.
- [`kubernetes-kserve-setup.md`](docs/setup/kubernetes-kserve-setup.md) —
  cluster bootstrap, KServe install, canary management.
- [`qgis-export-procedure.md`](docs/setup/qgis-export-procedure.md) — manual
  GeoPackage export procedure for the R+C data team.

---

## Split-Environment Note

Production runs on a Windows Server 2019 host (AMD Threadripper PRO,
dual NVIDIA RTX 4500 Ada, 128 GB RAM). WSL2 is unavailable on Windows
Server 2019, so Docker services run on a Linux guest VM while PostGIS and
JupyterHub run natively on the Windows guest. All framework development and
integration testing were carried out on the Linux host first.
See Section 4.4.9 of the thesis for the full split-environment design.

---

## License

MIT — see [LICENSE](LICENSE).