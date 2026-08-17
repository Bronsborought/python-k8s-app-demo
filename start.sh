#!/bin/bash

set -e

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
        echo "Minikube tunnel is already running."
else
        echo "Starting Minikube tunnel..."
        sudo -v
        minikube tunnel > tunnel.log 2>&1 < /dev/null &
        echo "Minikube tunnel started."
fi
echo

echo "Waiting for application pods..."
kubectl wait \
        --for=condition=Ready \
        pod \
        -l app=my-app \
        --timeout=120s
echo "Application pods are ready."
echo

echo "Checking local hostname..."
if ! getent hosts my-app.local > /dev/null; then
	echo "my-app.local is not configured. Adding..."
	echo "127.0.0.1 my-app.local" | sudo tee -a \
		 /etc/hosts > /dev/null
	echo "my-app.local was added."
fi
echo "my-app.local is configured"
echo

echo "Checking application..."
echo "Waiting for application to respond..."

for i in {1..20}; do
        if APP_RESPONSE=$(curl -fsS \
                --connect-timeout 3 --max-time 5 \
                http://my-app.local 2>/dev/null); then
                break
        fi

        if [ "$i" -eq 20 ]; then
                echo "Application failed to respond."
                exit 1
        fi

        sleep 3
done
echo

echo "Environment status:"
printf "%-25s %s\n" "Docker:" "running"
printf "%-25s %s\n" "Minikube:" "running"
printf "%-25s %s\n" "GitHub Actions Runner:" "running"
printf "%-25s %s\n" "Tunnel:" "running"
echo

echo "Kubernetes status:"
kubectl get pods
echo
kubectl get service
echo
kubectl get ingress
echo

echo "Application is responding:"
echo "$APP_RESPONSE"
echo
