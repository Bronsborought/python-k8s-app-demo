# Python Kubernetes CI/CD Demo

A simple Python application deployed to Kubernetes with Docker, Minikube, GitHub Actions, ConfigMap, Secret, health checks, Service, and Ingress.

## Architecture

```text
Git Push
   |
   v
GitHub Actions
   |
   +--> Build Docker image
   |
   +--> Push image to Docker Hub
   |
   +--> Update Kubernetes Deployment
   |
   v
Kubernetes
   |
   +--> Ingress
   |      |
   |      v
   +--> Service
          |
          v
      3 application Pods
```

## Technologies

- Python
- Docker
- Kubernetes
- Minikube
- GitHub Actions
- Docker Hub
- NGINX Ingress Controller
- Bash

## Application

The application runs a simple HTTP server on port `8000`.

The main endpoint:

```text
/
```

returns the configured application message and the name of the Pod that handled the request.

Example:

```text
Hello from ConfigMap | Pod: my-app-xxxxxxxxxx-xxxxx
```

The protected endpoint:

```text
/secret
```

requires a valid `X-API-Key` HTTP header.

Without a valid token it returns:

```text
401 Unauthorized
```

With the correct token:

```text
200 OK
Secret access granted
```

## Kubernetes

The application is deployed with 3 replicas.

The Kubernetes configuration includes:

- Deployment
- ClusterIP Service
- NGINX Ingress
- ConfigMap
- Secret
- Readiness probe
- Liveness probe
- Docker registry image pull secret

### ConfigMap

The application message is stored separately from the Docker image:

```text
APP_MESSAGE=Hello from ConfigMap
```

The Deployment loads it from `my-app-config`.

### Secret

The application uses `APP_SECRET` as an API token.

The Secret is created directly in Kubernetes and is not stored in Git.

Example:

```bash
kubectl create secret generic my-app-secret \
  --from-literal=APP_SECRET="$(openssl rand -hex 32)"
```

The Deployment loads the value using `secretKeyRef`.

## CI/CD

The GitHub Actions pipeline runs after a push to the `main` branch.

It:

1. Checks out the repository.
2. Logs in to Docker Hub.
3. Builds the Docker image.
4. Pushes the `latest` image.
5. Pushes an image tagged with the Git commit SHA.
6. Updates the Kubernetes Deployment to the commit-specific image.
7. Adds the Git commit SHA as the deployment change cause.
8. Waits for the Kubernetes rollout to complete.

Using the Git SHA as an image tag makes each deployment version identifiable and allows previous versions to be restored.

## Ingress

The application is available locally through:

```text
http://my-app.local
```

The request flow is:

```text
my-app.local
    |
    v
NGINX Ingress
    |
    v
my-app-service
    |
    v
Application Pods
```

Minikube tunnel is used to expose the Ingress locally.

## Local Environment Scripts

Start the environment:

```bash
./start.sh
```

The script:

- checks Docker
- starts Minikube if necessary
- starts the self-hosted GitHub Actions runner
- starts Minikube tunnel
- waits for application Pods to become Ready
- configures `my-app.local` in `/etc/hosts` if necessary
- verifies that the application responds
- displays the current environment and Kubernetes status

Stop the environment:

```bash
./stop.sh
```

The script stops:

- GitHub Actions runner
- Minikube tunnel
- Minikube

## Useful Commands

Check Kubernetes resources:

```bash
kubectl get pods
kubectl get service
kubectl get ingress
```

Check Deployment rollout:

```bash
kubectl rollout status deployment/my-app
```

View rollout history:

```bash
kubectl rollout history deployment/my-app
```

Test the application:

```bash
curl http://my-app.local
```

Test the protected endpoint without a token:

```bash
curl -i http://my-app.local/secret
```

Load the API token into a shell variable:

```bash
APP_SECRET=$(kubectl get secret my-app-secret \
  -o jsonpath='{.data.APP_SECRET}' | base64 -d)
```

Test the protected endpoint:

```bash
curl -i \
  -H "X-API-Key: $APP_SECRET" \
  http://my-app.local/secret
```
