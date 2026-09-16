# GKE Load Balancer Backend Model

The production application uses the GKE container-native load balancing model.

Traffic flow:

    Internet
      -> Google Cloud external HTTP Load Balancer
      -> Google Backend Service
      -> GKE Network Endpoint Group (NEG)
      -> application Pods on port 8000

The `my-app-service` Service is annotated for an ingress-managed NEG.

The GKE Ingress creates and manages:

- external forwarding rule
- target HTTP proxy
- URL map
- backend service
- health check
- network endpoint group

Validation confirmed:

- the Ingress backend is HEALTHY
- the NEG contains all three application Pod endpoints
- all three backend endpoints are HEALTHY
- application Pods are reached directly on port 8000
- public HTTP requests successfully reach the application through the Google Load Balancer
