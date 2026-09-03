#!/bin/bash

set -e

PRODUCTION_NAMESPACE="production"
APP_HOST="my-app.local"

start_tunnel() {
        echo "Starting Minikube tunnel..."

        sudo -v

        minikube tunnel > tunnel.log 2>&1 < /dev/null &

        echo "Minikube tunnel started."
}

wait_for_application() {
        for i in {1..20}; do
                if APP_RESPONSE=$(curl -fsS \
                        --connect-timeout 3 --max-time 5 \
                        "http://$APP_HOST" 2>/dev/null); then
                        return 0
                fi

                sleep 3
        done

        return 1
}


echo "Checking Docker..."
if ! docker info > /dev/null 2>&1; then
        echo "Docker is not running."
        exit 1
fi
echo "Docker is already running."
echo


echo "Checking Minikube..."
if minikube status > /dev/null 2>&1; then
        echo "Minikube is already running."
else
        echo "Starting Minikube..."
        minikube start
        echo "Minikube is running."
fi
echo


echo "Checking GitHub Actions runner..."
if pgrep -f "Runner.Listener run" > /dev/null; then
        echo "GitHub Actions runner is already running."
else
        echo "Starting GitHub Actions runner..."

        cd actions-runner
        ./run.sh > runner.log 2>&1 &
        cd ..

        echo "GitHub Actions runner started."
fi
echo


echo "Checking Minikube tunnel..."
if pgrep -f "minikube tunnel" > /dev/null; then
        echo "Minikube tunnel process is running."
else
        start_tunnel
fi
echo


echo "Waiting for production application pods..."
kubectl wait \
        --for=condition=Ready \
        pod \
        -l app=my-app \
        -n "$PRODUCTION_NAMESPACE" \
        --timeout=120s

echo "Production application pods are ready."
echo


echo "Checking local hostname..."
if ! getent hosts "$APP_HOST" > /dev/null; then
        echo "$APP_HOST is not configured. Adding..."

        echo "127.0.0.1 $APP_HOST" | sudo tee -a \
                 /etc/hosts > /dev/null

        echo "$APP_HOST was added."
fi

echo "$APP_HOST is configured."
echo


echo "Checking application..."
echo "Waiting for application to respond..."

if ! wait_for_application; then
        echo "Application is not reachable."
        echo "Restarting Minikube tunnel..."

        pkill -f "minikube tunnel" > /dev/null 2>&1 || true
        sleep 2

        start_tunnel

        echo "Waiting for application after tunnel restart..."

        if ! wait_for_application; then
                echo "Application failed to respond after tunnel restart."
                exit 1
        fi
fi

echo "Application is responding."
echo


echo "Environment status:"
printf "%-25s %s\n" "Docker:" "running"
printf "%-25s %s\n" "Minikube:" "running"
printf "%-25s %s\n" "GitHub Actions Runner:" "running"
printf "%-25s %s\n" "Tunnel:" "running"
echo


echo "Production Kubernetes status:"
kubectl get pods -n "$PRODUCTION_NAMESPACE"
echo

kubectl get service -n "$PRODUCTION_NAMESPACE"
echo

kubectl get ingress -n "$PRODUCTION_NAMESPACE"
echo


echo "Application response:"
echo "$APP_RESPONSE"
echo
