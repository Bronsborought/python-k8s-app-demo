# Manual GKE Deployment

This document describes the initial manual deployment of the production application to GKE.

## Target cluster

- GCP project: `python-k8s-app-demo-dt26`
- GKE cluster: `python-k8s-app`
- Region: `europe-central2`
- Kubernetes namespace: `production`

## Refresh GKE credentials

    gcloud container clusters get-credentials python-k8s-app \
      --location=europe-central2 \
      --project=python-k8s-app-demo-dt26

## Deploy application resources

Create the production namespace:

    kubectl apply -f k8s/production/namespace.yml

Apply the production ConfigMap:

    kubectl apply -f k8s/production/configmap.yml

Apply the Deployment:

    kubectl apply -f k8s/production/deployment.yml

Apply the Service:

    kubectl apply -f k8s/production/service.yml

## Current temporary dependencies

The initial GKE deployment still uses:

- Docker Hub for the application image
- `dockerhub-secret` as an image pull secret
- Kubernetes `my-app-secret` for `APP_SECRET`

These are temporary migration steps.

Artifact Registry migration is handled separately.
Application secrets will later move to Google Secret Manager with Workload Identity.

## Validation

Verify rollout:

    kubectl rollout status deployment/my-app \
      -n production \
      --timeout=300s

Verify Pods:

    kubectl get pods -n production -o wide

Verify Service:

    kubectl get service my-app-service -n production

Verify Service backends:

    kubectl get endpoints my-app-service -n production

The initial migration was validated with:

- 3/3 application Pods Running
- zero Pod restarts
- `/health` returning HTTP 200
- `/ready` returning HTTP 200
- `/` returning the production application response
- `/secret` returning HTTP 401 without an API key
- `/secret` returning HTTP 200 with the correct API key
