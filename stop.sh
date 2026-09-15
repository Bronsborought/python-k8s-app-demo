#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RUNTIME_DIR="$SCRIPT_DIR/.runtime"
RUNNER_PGID_FILE="$RUNTIME_DIR/runner.pgid"
TUNNEL_PID_FILE="$RUNTIME_DIR/tunnel.pid"


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


stop_managed_group() {
    local name="$1"
    local pgid_file="$2"
    local expected="$3"
    local pgid

    echo "Stopping $name..."

    if ! process_group_matches "$pgid_file" "$expected"; then
        rm -f "$pgid_file"
        echo "$name is not running."
        return
    fi

    pgid="$(cat "$pgid_file")"

    kill -- "-$pgid" 2>/dev/null || true

    for _ in {1..20}; do
        if ! kill -0 -- "-$pgid" 2>/dev/null; then
            rm -f "$pgid_file"
            echo "$name stopped."
            return
        fi

        sleep 0.5
    done

    kill -KILL -- "-$pgid" 2>/dev/null || true
    rm -f "$pgid_file"

    echo "$name stopped."
}


stop_managed_process() {
    local name="$1"
    local pid_file="$2"
    local expected="$3"
    local pid

    echo "Stopping $name..."

    if ! process_matches "$pid_file" "$expected"; then
        rm -f "$pid_file"
        echo "$name is not running."
        return
    fi

    pid="$(cat "$pid_file")"

    kill "$pid"

    for _ in {1..20}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$pid_file"
            echo "$name stopped."
            return
        fi
        sleep 0.5
    done

    if process_matches "$pid_file" "$expected"; then
        kill -KILL "$pid"
    fi

    rm -f "$pid_file"
    echo "$name stopped."
}


stop_managed_group \
    "GitHub Actions runner" \
    "$RUNNER_PGID_FILE" \
    "Runner.Listener run"

echo

stop_managed_process \
    "Minikube tunnel" \
    "$TUNNEL_PID_FILE" \
    "minikube tunnel"

echo

echo "Stopping Minikube..."
if minikube status >/dev/null 2>&1; then
    minikube stop
    echo "Minikube stopped."
else
    echo "Minikube is not running."
fi
echo
