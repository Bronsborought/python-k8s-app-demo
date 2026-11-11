# Architecture Decision Records (ADR)

## ADR-01: CI/CD Execution Model — GitHub-Hosted Runners + OIDC WIF vs. Actions Runner Controller (ARC)

### Context (Roadmap #58–59)
We evaluated two models for running CI/CD pipelines deploying to Google Kubernetes Engine (GKE):
1. **GitHub-Hosted Runners with OpenID Connect (OIDC) Workload Identity Federation (WIF)**
2. **Self-Hosted Ephemeral Kubernetes Runners via Actions Runner Controller (ARC)** inside the GKE cluster

### Comparison
| Dimension | GitHub-Hosted + OIDC WIF (Selected) | Actions Runner Controller (ARC) on GKE |
|---|---|---|
| **Credential Security** | Short-lived OIDC tokens exchanged via GCP STS; zero static keys in GitHub | Pod-level GKE Workload Identity or GitHub App secret stored inside cluster |
| **Cost on GKE Autopilot** | Free tier / zero idle compute in GCP | Autopilot bills per pod request/minute; idle runner controller + webhook pods consume baseline GCP budget |
| **Cluster Blast Radius** | CI builds run outside the production cluster; Docker builds cannot starve production pods | Privileged/rootless DinD or Kaniko builds run inside the cluster and compete for cluster quotas |
| **Bootstrap Dependency** | Can run `terraform apply` and deploy even when GKE cluster is recreated from scratch | Chicken-and-egg problem: cannot run pipelines if the GKE cluster hosting ARC is down or destroyed for cost control |

### Decision
We selected **GitHub-Hosted Runners with GCP Workload Identity Federation (WIF)** for this single-service GKE Autopilot architecture. It eliminates idle GKE Autopilot runner costs, avoids privileged container builds inside the production cluster, and allows clean cluster teardown/recreation (`terraform/CLEANUP.md`) without breaking the CI/CD control plane.

---

## ADR-02: GKE Autopilot with Container-Native Load Balancing (NEG) & Cloud Armor

### Decision
- **GKE Autopilot** was chosen over GKE Standard to delegate node hardening, seccomp defaults, and node auto-provisioning to Google Cloud.
- **Container-Native Load Balancing (`cloud.google.com/neg: '{"ingress": true}'`)** routes traffic from the external Google Cloud HTTPS Load Balancer directly to Pod IPs without an extra `kube-proxy` NodePort hop.
- **Google-Managed SSL Certificates (`ManagedCertificate`) + `FrontendConfig`** enforce automatic HTTPS provisioning for `app.tarakanovds.lol` and HTTP-to-HTTPS `301 MOVED_PERMANENTLY` redirects at the edge.
- **Cloud Armor (`BackendConfig`)** enforces edge rate limiting (`100 req/min` per IP) and OWASP preconfigured WAF rules (`xss-v33-stable`, `sqli-v33-stable`) before traffic enters the cluster.

---

## ADR-03: Dual Secret Delivery (Google Secret Manager CSI + Environment Fallback)

### Decision
Application secrets (`APP_SECRET`) are stored in **Google Secret Manager** and mounted into GKE Pods via the **Secrets Store CSI Driver (`SecretProviderClass`)** using Pod-level **GKE Workload Identity** (`roles/secretmanager.secretAccessor`). The FastAPI application resolves `/var/secrets/APP_SECRET` first and falls back to `APP_SECRET` environment variable for local Minikube/pytest compatibility, failing closed (`RuntimeError`) if neither is present.
