#!/bin/bash

echo "Stopping GitHub Actions runner..."
if pgrep -f "Runner.Listener run" > /dev/null; then
        pkill -f "Runner.Listener run"
        echo "GitHub Actions runner stopped."
else
        echo "GitHub Actions runner is not running."
fi
echo

echo "Stopping Minikube tunnel..."
if pgrep -f "minikube tunnel" > /dev/null; then
        pkill -f "minikube tunnel"
        echo "Minikube tunnel stopped."
else
        echo "Minikube tunnel is not running."
fi
echo

echo "Stopping Minikube..."
if minikube status > /dev/null 2>&1; then
        minikube stop
        echo "Minikube stopped."
else
        echo "Minikube is not running."
fi
echo
