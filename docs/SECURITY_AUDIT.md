# Final Security & Reproducibility Audit (Roadmap #60–61)

## 1. Container & Application Hardening
- **Non-Root Execution:** Dockerfile and Kubernetes `securityContext` enforce UID/GID `10001` (`runAsNonRoot: true`).
- **Immutable Filesystem:** `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, Linux capabilities `drop: ["ALL"]`, `seccompProfile: RuntimeDefault`.
- **Fail-Closed Secret Handling:** Application refuses to start if `APP_SECRET` is missing or empty; `/secret` returns `401 Unauthorized` on missing/invalid `X-API-Key`.
- **Attack Surface Reduction:** FastAPI interactive docs (`docs_url`, `redoc_url`, `openapi_url`) are disabled in production.

## 2. IAM, CI/CD & Supply Chain Security
- **Zero Static Cloud Keys:** GitHub Actions authenticates to GCP exclusively via OIDC Workload Identity Federation (`terraform/workload-identity.tf`).
- **Least-Privilege IAM:** Deploy service account is scoped to `roles/artifactregistry.writer` and `roles/container.developer`; application pod service account is scoped only to `roles/secretmanager.secretAccessor` on the single secret.
- **Immutable Image Tags:** Deployments use exact commit SHA tags (`${GITHUB_SHA}`) rather than mutable `:latest` tags.

## 3. Network & Edge Security
- **Global Static IP Reservation in IaC:** Reserved via `google_compute_global_address.ingress_ip` (`my-app-gke-ip`) in `terraform/network.tf` and bound to `k8s/gke/production/ingress.yml`.
- **TLS & HTTPS Redirect:** Managed via `ManagedCertificate` (`app.tarakanovds.lol`) and `FrontendConfig` (`redirectToHttps: PERMANENT_REDIRECT`).
- **Cloud Armor WAF:** `my-app-armor-policy` enforces IP rate-limiting and blocks SQLi/XSS at the Google Cloud Load Balancer edge.

## 4. Reproducibility & Clean Teardown Procedure
1. **Provision Infrastructure:** `terraform -chdir=terraform apply` provisions APIs, Artifact Registry, WIF, GKE Autopilot, Cloud Armor, Global Static IP (`my-app-gke-ip`), and Cloud Monitoring alerts.
2. **Update DNS:** Point `app.tarakanovds.lol` A-record to `terraform -chdir=terraform output -raw ingress_static_ip_address`.
3. **Safe Teardown Order:** Delete the Kubernetes Ingress first (`kubectl delete ingress my-app-ingress -n production`) and verify forwarding-rule removal before destroying the GKE cluster (`terraform -chdir=terraform destroy -target=google_container_cluster.autopilot`) so no orphaned Load Balancer resources remain.
