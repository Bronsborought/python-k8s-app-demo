# Terraform Cost and Cleanup Guardrails

## Budget

The project has a monthly budget managed by Terraform:

- $20 USD monthly budget
- 50% current spend alert
- 80% current spend alert
- 100% current spend alert
- 100% forecasted spend alert

Budget alerts notify about spending but do not automatically stop resources.

## Cost-sensitive resources

The main cost-sensitive resource is the GKE Autopilot cluster:

`google_container_cluster.autopilot`

IAM, Service Accounts and Workload Identity Federation do not need cleanup for cost control.

## GKE cleanup

Preview destruction:

    terraform -chdir=terraform plan -destroy \
      -target=google_container_cluster.autopilot

Destroy only the GKE cluster:

    terraform -chdir=terraform destroy \
      -target=google_container_cluster.autopilot

Verify that the cluster was removed:

    gcloud container clusters list \
      --project=python-k8s-app-demo-dt26

Recreate the cluster:

    terraform -chdir=terraform apply

## Remote state protection

The Terraform state bucket uses `prevent_destroy = true`.

Do not delete the remote state bucket during normal cost cleanup.

The bucket contains the remote Terraform state and must remain available while Terraform uses the GCS backend.

A complete teardown including the state bucket requires migrating Terraform state away from the GCS backend first.
