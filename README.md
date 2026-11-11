# Python Kubernetes & GKE Cloud-Native CI/CD Platform

An end-to-end cloud-native Python (**FastAPI**) platform demonstrating the complete lifecycle of modern application delivery — from **automated local Kubernetes provisioning (Minikube, Ansible, Prometheus, Grafana, Loki, Fluent Bit)** to **production Google Cloud infrastructure (GKE Autopilot, Terraform, Workload Identity Federation, Secret Manager CSI, Container-Native Load Balancing, Cloud Armor WAF, and Google Managed Prometheus)**.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Repository Structure](#2-repository-structure)
3. [Application Specification & Hardening](#3-application-specification--hardening)
4. [Production Cloud Infrastructure (Terraform & GCP)](#4-production-cloud-infrastructure-terraform--gcp)
5. [Kubernetes Topologies (GKE & Local Minikube)](#5-kubernetes-topologies-gke--local-minikube)
6. [CI/CD Pipelines & Automated Rollback](#6-cicd-pipelines--automated-rollback)
7. [Observability, Logging & Alerting](#7-observability-logging--alerting)
8. [Local Workstation Automation (Ansible & Scripts)](#8-local-workstation-automation-ansible--scripts)
9. [Operations & Verification Runbook](#9-operations--verification-runbook)
10. [Cost Guardrails & Infrastructure Teardown](#10-cost-guardrails--infrastructure-teardown)

---

## 1. Architecture Overview

### Production Cloud Architecture (Google Cloud & GKE Autopilot)

```text
Developer (git push main)
   |
   v
GitHub Actions (.github/workflows/cloud-cd.yml)
   |-- [Job 1: test]         Run pytest suite on Python 3.14
   |-- [Job 2: build-push]   Keyless OIDC auth (Workload Identity Federation)
   |                         Build & push immutable SHA image to Artifact Registry
   |-- [Job 3: deploy-stage] Roll out to GKE 'staging' namespace & run in-cluster smoke tests
   |-- [Job 4: deploy-prod]  Roll out to GKE 'production' namespace, verify endpoints,
   |                         and trigger automatic 'kubectl rollout undo' on failure
   v
Google Cloud Platform (Project: python-k8s-app-demo-dt26, Region: europe-central2)
   |
   +--> Cloud Armor WAF Security Policy (Rate limiting & L7 protection)
           |
           v
        Google Cloud External HTTP(S) Load Balancer (Managed SSL Certificate)
           |
           v
        Container-Native Load Balancing (Network Endpoint Group / NEG)
           |
           v
        GKE Autopilot Cluster (python-k8s-app)
           |-- Namespace: staging      (Pre-production verification)
           |-- Namespace: production   (3 FastAPI Pod replicas, non-root execution)
           |-- Secret Manager CSI      (SecretProviderClass mounts /var/secrets/APP_SECRET)
           |-- Observability           (Google Managed Prometheus PodMonitoring +
                                        Structured JSON Cloud Logging + Cloud Monitoring Alerts)
```

### Local Development Architecture (Minikube, Ansible & Self-Hosted Observability)

```text
./bootstrap.sh (Ansible Playbook + Custom Module dev_environment_status.py)
   |
   +--> Docker Engine + Minikube Cluster + NGINX Ingress Controller
   +--> Self-Hosted GitHub Actions Runner (.github/workflows/ci-cd.yml)
   +--> Local Application Namespaces (staging & production, http://my-app.local)
   +--> In-Cluster Observability Stack (k8s/monitoring/):
          |-- Prometheus   (Scrapes /metrics, evaluates alert rules)
          |-- Grafana      (Pre-provisioned dashboards & Prometheus/Loki datasources)
          |-- Fluent Bit   (DaemonSet shipping container logs)
          |-- Loki         (Centralized log aggregation)
```

---

## 2. Repository Structure

```text
.
├── .github/workflows/
│   ├── cloud-cd.yml                  # Multi-stage GCP/GKE CI/CD pipeline with auto-rollback
│   ├── manual-deploy.yml             # On-demand image tag deployment / rollback workflow
│   └── ci-cd.yml                     # Local Minikube CI/CD pipeline (self-hosted runner)
├── ansible/
│   ├── inventory.ini                 # Local workstation inventory
│   ├── playbook.yml                  # Idempotent Ansible bootstrap for Docker/Minikube/K8s
│   └── library/
│       └── dev_environment_status.py # Custom Ansible module reporting environment readiness
├── k8s/
│   ├── gke/                          # Production GKE Autopilot manifests
│   │   ├── BACKEND_MODEL.md          # Container-native NEG load balancing documentation
│   │   ├── staging/                  # GKE staging deployment, service, WIF SA, Secret CSI
│   │   └── production/               # GKE production Ingress, ManagedCertificate, BackendConfig
│   ├── monitoring/                   # Self-hosted Prometheus, Grafana, Loki & Fluent Bit stack
│   ├── staging/                      # Local Minikube staging manifests
│   ├── production/                   # Local Minikube production manifests
│   └── GKE_MANUAL_DEPLOY.md          # Step-by-step manual GKE deployment & validation guide
├── terraform/
│   ├── main.tf                       # GCP API service enablement
│   ├── backend.tf & state.tf         # Versioned GCS remote state bucket (prevent_destroy)
│   ├── gke.tf                        # GKE Autopilot cluster definition
│   ├── artifact-registry.tf          # Docker repository in Google Artifact Registry
│   ├── github-actions-iam.tf         # Keyless Workload Identity Pool & OIDC Provider for GitHub
│   ├── workload-identity.tf          # GKE Workload Identity & Secret Manager IAM bindings
│   ├── cloud-armor.tf                # Cloud Armor WAF policy attached to GKE Ingress backend
│   ├── alerts.tf                     # Cloud Monitoring alerting policies (error rate, latency)
│   ├── budget.tf                     # Monthly GCP budget ($20) with 50%/80%/100% alert thresholds
│   └── CLEANUP.md                    # Cost management and targeted cluster teardown guide
├── tests/
│   └── test_app.py                   # Automated pytest suite covering all HTTP endpoints
├── app.py                            # FastAPI application with Prometheus metrics & JSON logs
├── Dockerfile                        # Multi-stage hardened container build
├── bootstrap.sh                      # End-to-end workstation & cluster provisioning entrypoint
├── start.sh                          # Starts Minikube, self-hosted runner, tunnel & verification
└── stop.sh                           # Gracefully stops runner, Ingress tunnel & Minikube
```

---

## 3. Application Specification & Hardening

The service (`app.py`) is built with **FastAPI** and **Prometheus Client** and runs on port `8000`.

### HTTP Endpoints

| Endpoint | Method | Auth | Response & Behavior |
| --- | --- | --- | --- |
| `/` | `GET` | Public | Returns `<APP_MESSAGE> \| Pod: <HOSTNAME>` (`200 OK`) |
| `/health` | `GET` | Public | Liveness probe returning `Healthy` (`200 OK`) |
| `/ready` | `GET` | Public | Readiness probe verifying `APP_SECRET` is loaded (`200 OK` or `503 Not ready`) |
| `/secret` | `GET` | `X-API-Key` | Returns `Secret access granted` (`200 OK`), `401 Unauthorized` on invalid key, or `503` if unconfigured |
| `/metrics` | `GET` | Public | Exposes Prometheus metrics (`CONTENT_TYPE_LATEST`) |

### Security & Observability Features in `app.py`

- **Dual Secret Resolution:** Supports both environment injection (`APP_SECRET`) for local development and volume-mounted secrets (`/var/secrets/APP_SECRET`) provisioned dynamically by the **Google Secret Manager CSI Driver** in GKE.
- **Structured JSON Logging:** Every HTTP request emits a single-line JSON payload to `stdout` (`severity`, `event`, `method`, `path`, `status_code`, `duration_seconds`), natively parsed by **Google Cloud Logging** and **Fluent Bit / Loki**.
- **RED Metrics Instrumentation:** Tracks request rate, error count, and duration via Prometheus metrics:
  - `http_requests_total{method, path, status_code}`
  - `http_request_duration_seconds_bucket{method, path, le}`
  - `http_request_errors_total{method, path, status_code}`

---

## 4. Production Cloud Infrastructure (Terraform & GCP)

All Google Cloud resources are declaratively managed under `terraform/`:

| File | Responsibility |
| --- | --- |
| `main.tf` | Enables required GCP APIs (`container`, `artifactregistry`, `secretmanager`, `monitoring`, `logging`, `compute`, `iamcredentials`, `billingbudgets`). |
| `state.tf` & `backend.tf` | Provisions and configures a versioned GCS bucket for remote Terraform state with `prevent_destroy = true`. |
| `gke.tf` | Creates the regional **GKE Autopilot** cluster (`python-k8s-app` in `europe-central2`) with Secret Manager CSI and Managed Prometheus enabled. |
| `artifact-registry.tf` | Creates a private Docker repository (`python-k8s-app`) in Google Artifact Registry. |
| `github-actions-iam.tf` | Configures a **Workload Identity Pool & OIDC Provider** allowing GitHub Actions (`Bronsborought/python-k8s-app-demo`) to authenticate without static service account keys. |
| `workload-identity.tf` | Binds Kubernetes Service Accounts (`staging` and `production`) to GCP IAM roles for Secret Manager access. |
| `cloud-armor.tf` | Defines a **Google Cloud Armor** security policy protecting the public load balancer backend. |
| `alerts.tf` | Configures **Cloud Monitoring** alert policies for elevated HTTP 5xx error rates, high request latency, and Pod restart anomalies. |
| `budget.tf` | Enforces a $20 USD monthly budget with automated email notifications at 50%, 80%, and 100% spend. |

### Terraform Commands

```bash
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

---

## 5. Kubernetes Topologies (GKE & Local Minikube)

### GKE Production & Staging (`k8s/gke/`)

- **Container-Native Load Balancing (NEG):** The `my-app-service` Service uses `cloud.google.com/neg: '{"ingress": true}'`, allowing the Google Cloud external HTTP(S) Load Balancer to route traffic directly to Pod IPs without intermediate `kube-proxy` node hops (see [k8s/gke/BACKEND_MODEL.md](k8s/gke/BACKEND_MODEL.md)).
- **Edge Security & TLS:** Configured via `BackendConfig` (Cloud Armor policy attachment and custom health checks), `FrontendConfig`, and Google-managed SSL certificates (`ManagedCertificate`).
- **Secret Manager CSI Integration:** `SecretProviderClass` mounts the secret directly from Google Secret Manager into Pods at `/var/secrets/APP_SECRET`.

### Local Minikube (`k8s/staging/`, `k8s/production/`)

- Deploys 3 replicas behind a `ClusterIP` Service and NGINX Ingress (`http://my-app.local`).
- Separates configuration (`ConfigMap` `my-app-config`) from credentials (`Secret` `my-app-secret` and `dockerhub-secret`).

---

## 6. CI/CD Pipelines & Automated Rollback

### 1. Cloud GKE Pipeline (`.github/workflows/cloud-cd.yml`)

Triggered automatically on push to `main` or manual dispatch:
1. **`test`:** Runs `pytest -v` on Python 3.14.
2. **`build-and-push`:** Authenticates to GCP via Workload Identity Federation (`google-github-actions/auth@v2`), builds the Docker image, and pushes `:latest` and `:<git-sha>` to Google Artifact Registry.
3. **`deploy-staging`:** Updates the `staging` deployment in GKE, waits for rollout completion, and executes an in-cluster smoke test Pod verifying `/health`, `/ready`, `/`, and `/secret` (`401` and `200`).
4. **`deploy-production`:** Updates the `production` deployment only after `staging` passes. If the production rollout or post-deploy verification fails, the workflow automatically executes **`kubectl rollout undo deployment/my-app -n production`** and verifies recovery.

### 2. Manual Deploy & Rollback Workflow (`.github/workflows/manual-deploy.yml`)

Allows operators to deploy any specific image tag or perform an immediate controlled rollback in `staging` or `production` via `workflow_dispatch`.

### 3. Local Minikube Pipeline (`.github/workflows/ci-cd.yml`)

Builds and pushes images to Docker Hub and rolls out updates to the local Minikube cluster through a self-hosted GitHub Actions runner.

---

## 7. Observability, Logging & Alerting

### Cloud Observability (GKE)

- **Metrics:** `k8s/gke/*/pod-monitoring.yml` defines `PodMonitoring` resources scraped by **Google Cloud Managed Service for Prometheus** at `/metrics` on port `8000`.
- **Logs:** Structured JSON request logs are automatically ingested by **Cloud Logging** with severity and latency fields indexed.
- **Alerts:** Terraform-managed **Cloud Monitoring Alert Policies** (`terraform/alerts.tf`) monitor container restarts, HTTP 5xx rates, and latency thresholds.

### Local Observability Stack (`k8s/monitoring/`)

Deployed into the `monitoring` namespace on Minikube:
- **Prometheus:** `prometheus-deployment.yml`, `prometheus-configmap.yml`, and `prometheus-rules.yml` (alerting rules).
- **Grafana:** `grafana-deployment.yml` with pre-configured datasources (`grafana-datasource.yml`) and application dashboards (`grafana-dashboard.yml`).
- **Loki & Fluent Bit:** `fluent-bit-daemonset.yml` tails container logs across nodes and ships them to `loki-deployment.yml`.

---

## 8. Local Workstation Automation (Ansible & Scripts)

- **`bootstrap.sh` & `ansible/playbook.yml`:** Automates installation and verification of Docker, `kubectl`, Minikube, Helm, and cluster addons, using the custom Ansible module `ansible/library/dev_environment_status.py`.
- **`start.sh`:** Starts Docker/Minikube, registers/starts the self-hosted GitHub Actions runner, opens `minikube tunnel`, configures `/etc/hosts` for `my-app.local`, and runs readiness checks.
- **`stop.sh`:** Stops the runner, Ingress tunnel, and Minikube cleanly.

---

## 9. Operations & Verification Runbook

### Run Automated Tests Locally

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
pytest -v
```

### Verify Local Minikube Deployment

```bash
kubectl get pods,svc,ingress -n production
kubectl rollout status deployment/my-app -n production
kubectl rollout history deployment/my-app -n production

curl -i http://my-app.local/
curl -i http://my-app.local/health
curl -i http://my-app.local/ready
curl -i http://my-app.local/secret

APP_SECRET=$(kubectl get secret my-app-secret -n production -o jsonpath='{.data.APP_SECRET}' | base64 -d)
curl -i -H "X-API-Key: $APP_SECRET" http://my-app.local/secret
```

### Connect to GKE Cluster & Inspect Production

```bash
gcloud container clusters get-credentials python-k8s-app \
  --location=europe-central2 \
  --project=python-k8s-app-demo-dt26

kubectl get pods,svc,ingress -n staging
kubectl get pods,svc,ingress -n production
```

See [k8s/GKE_MANUAL_DEPLOY.md](k8s/GKE_MANUAL_DEPLOY.md) for initial GKE bootstrap instructions.

---

## 10. Cost Guardrails & Infrastructure Teardown

To prevent idle cloud charges while preserving IAM, Workload Identity Federation, Artifact Registry, and remote Terraform state, destroy only the GKE Autopilot cluster when not in active use:

```bash
terraform -chdir=terraform destroy -target=google_container_cluster.autopilot
```

To recreate the cluster later:

```bash
terraform -chdir=terraform apply
```

See [terraform/CLEANUP.md](terraform/CLEANUP.md) for full cost-control guidelines.
