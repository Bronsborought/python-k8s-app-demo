#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

STAGING_NAMESPACE="staging"
PRODUCTION_NAMESPACE="production"
PRODUCTION_HOST="my-app.local"
STAGING_HOST="staging.my-app.local"

RUNTIME_DIR="$SCRIPT_DIR/.runtime"
RUNNER_PGID_FILE="$RUNTIME_DIR/runner.pgid"
TUNNEL_PID_FILE="$RUNTIME_DIR/tunnel.pid"
TUNNEL_LOG="$SCRIPT_DIR/tunnel.log"

mkdir -p "$RUNTIME_DIR"

echo "Checking administrator access..."
sudo -v
echo "Administrator access confirmed."
echo


process_matches() {
    local pid_file="$1"
    local expected="$2"
    local pid
    local cmdline

    [ -f "$pid_file" ] || return 1

    pid="$(cat "$pid_file" 2>/dev/null || true)"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1

    kill -0 "$pid" 2>/dev/null || return 1
    [ -r "/proc/$pid/cmdline" ] || return 1

    cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline")"

    [[ "$cmdline" == *"$expected"* ]]
}


process_group_matches() {
    local pgid_file="$1"
    local expected="$2"
    local pgid

    [ -f "$pgid_file" ] || return 1

    pgid="$(cat "$pgid_file" 2>/dev/null || true)"
    [[ "$pgid" =~ ^[0-9]+$ ]] || return 1

    ps -eo pgid=,args= |
        awk -v pgid="$pgid" -v expected="$expected" '
            $1 == pgid && index($0, expected) > 0 {
                found = 1
            }
            END {
                exit found ? 0 : 1
            }
        '
}


stop_managed_process() {
    local pid_file="$1"
    local expected="$2"
    local pid

    if ! process_matches "$pid_file" "$expected"; then
        rm -f "$pid_file"
        return 0
    fi

    pid="$(cat "$pid_file")"
    kill "$pid"

    for _ in {1..20}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$pid_file"
            return 0
        fi
        sleep 0.5
    done

    if process_matches "$pid_file" "$expected"; then
        kill -KILL "$pid"
    fi

    rm -f "$pid_file"
}


start_runner() {
    local runner_pgid

    if process_group_matches "$RUNNER_PGID_FILE" "Runner.Listener run"; then
        echo "GitHub Actions runner is already running."
        return
    fi

    rm -f "$RUNNER_PGID_FILE"

    echo "Starting GitHub Actions runner..."

    setsid bash -c '
        cd "$1"
        exec ./run.sh
    ' _ "$SCRIPT_DIR/actions-runner" \
        > "$SCRIPT_DIR/actions-runner/runner.log" 2>&1 < /dev/null &

    runner_pgid=$!
    echo "$runner_pgid" > "$RUNNER_PGID_FILE"

    sleep 2

    if ! process_group_matches "$RUNNER_PGID_FILE" "Runner.Listener run"; then
        rm -f "$RUNNER_PGID_FILE"
        echo "GitHub Actions runner failed to start."
        exit 1
    fi

    echo "GitHub Actions runner started."
}


start_tunnel() {
    if process_matches "$TUNNEL_PID_FILE" "minikube tunnel"; then
        echo "Minikube tunnel is already running."
        return
    fi

    rm -f "$TUNNEL_PID_FILE"

    echo "Starting Minikube tunnel..."

    nohup minikube tunnel > "$TUNNEL_LOG" 2>&1 < /dev/null &
    echo $! > "$TUNNEL_PID_FILE"

    sleep 2

    if ! process_matches "$TUNNEL_PID_FILE" "minikube tunnel"; then
        rm -f "$TUNNEL_PID_FILE"
        echo "Minikube tunnel failed to start."
        exit 1
    fi

    echo "Minikube tunnel started."
}


wait_for_application() {
    local host="$1"

    for _ in {1..20}; do
        if APP_RESPONSE=$(curl -fsS \
            --connect-timeout 3 \
            --max-time 5 \
            "http://$host" 2>/dev/null); then
            return 0
        fi

        sleep 3
    done

    return 1
}


check_applications() {
    local failed=0

    echo "  Production:"
    if wait_for_application "$PRODUCTION_HOST"; then
        PRODUCTION_RESPONSE="$APP_RESPONSE"
        echo "    responding"
    else
        echo "    not reachable"
        failed=1
    fi

    echo "  Staging:"
    if wait_for_application "$STAGING_HOST"; then
        STAGING_RESPONSE="$APP_RESPONSE"
        echo "    responding"
    else
        echo "    not reachable"
        failed=1
    fi

    return "$failed"
}


echo "Checking Docker..."
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running."
    exit 1
fi
echo "Docker is running."
echo


echo "Checking Minikube..."
if minikube status >/dev/null 2>&1; then
    echo "Minikube is already running."
else
    echo "Starting Minikube..."
    minikube start
    echo "Minikube is running."
fi
echo


echo "Checking GitHub Actions runner..."
start_runner
echo


echo "Checking Minikube tunnel..."
start_tunnel
echo


echo "Waiting for application pods..."

for NAMESPACE in "$PRODUCTION_NAMESPACE" "$STAGING_NAMESPACE"; do
    echo "  $NAMESPACE:"

    kubectl wait \
        --for=condition=Ready \
        pod \
        -l app=my-app \
        -n "$NAMESPACE" \
        --timeout=120s

    echo "    application pods are ready."
done
echo


echo "Checking local hostnames..."

for HOST in "$PRODUCTION_HOST" "$STAGING_HOST"; do
    if ! getent hosts "$HOST" >/dev/null; then
        echo "$HOST is not configured. Adding..."

        echo "127.0.0.1 $HOST" |
            sudo tee -a /etc/hosts >/dev/null
    fi

    echo "$HOST is configured."
done
echo


echo "Checking applications..."

if ! check_applications; then
    echo "At least one application is not reachable."
    echo "Restarting managed tunnel..."

    stop_managed_process "$TUNNEL_PID_FILE" "minikube tunnel"
    start_tunnel

    echo "Checking applications after tunnel restart..."

    if ! check_applications; then
        echo "At least one application failed to respond after tunnel restart."
        exit 1
    fi
fi

echo


echo "Environment status:"
printf "%-25s %s\n" "Docker:" "running"
printf "%-25s %s\n" "Minikube:" "running"
printf "%-25s %s\n" "GitHub Actions Runner:" "running"
printf "%-25s %s\n" "Tunnel:" "running"
echo


echo "Kubernetes application status:"

for NAMESPACE in "$PRODUCTION_NAMESPACE" "$STAGING_NAMESPACE"; do
    echo
    echo "  ===== $NAMESPACE ====="

    kubectl get pods -n "$NAMESPACE"
    echo

    kubectl get service -n "$NAMESPACE"
    echo

    kubectl get ingress -n "$NAMESPACE"
done

echo
echo "Application responses:"
echo "  Production: $PRODUCTION_RESPONSE"
echo "  Staging:    $STAGING_RESPONSE"
echo
