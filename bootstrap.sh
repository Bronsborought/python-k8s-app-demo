#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BOOTSTRAP_USER="$(id -un)"

if ! command -v apt-get >/dev/null 2>&1; then
    echo "This bootstrap currently supports Ubuntu/Debian systems only."
    exit 1
fi

BECOME_PASSWORD_FILE=""

cleanup() {
    if [ -n "$BECOME_PASSWORD_FILE" ]; then
        rm -f "$BECOME_PASSWORD_FILE"
    fi
}

trap cleanup EXIT

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    if command -v sudo.ws >/dev/null 2>&1; then
        SUDO="$(command -v sudo.ws)"
    elif command -v sudo >/dev/null 2>&1; then
        SUDO="$(command -v sudo)"
    else
        echo "sudo is not available. Run this script as root or install sudo first."
        exit 1
    fi

    read -rsp "Administrator password: " BECOME_PASSWORD
    echo

    if ! printf '%s\n' "$BECOME_PASSWORD" | "$SUDO" -S -v >/dev/null 2>&1; then
        echo "Invalid administrator password."
        exit 1
    fi

    BECOME_PASSWORD_FILE="$(mktemp)"
    chmod 600 "$BECOME_PASSWORD_FILE"
    printf '%s\n' "$BECOME_PASSWORD" > "$BECOME_PASSWORD_FILE"
fi

echo "Installing bootstrap prerequisites..."

if [ "$(id -u)" -eq 0 ]; then
    apt-get update
    apt-get install -y sudo python3 ansible git
else
    "$SUDO" -n apt-get update
    "$SUDO" -n apt-get install -y sudo python3 ansible git
fi

echo "Running Ansible bootstrap..."

if [ "$(id -u)" -eq 0 ]; then
    ansible-playbook \
        -i ansible/inventory.ini \
        ansible/playbook.yml \
        -e ansible_become=false \
        -e "bootstrap_user=$BOOTSTRAP_USER"
else
    ansible-playbook \
        -i ansible/inventory.ini \
        ansible/playbook.yml \
        -e "ansible_become_exe=$SUDO" \
        -e "bootstrap_user=$BOOTSTRAP_USER" \
        --become-password-file "$BECOME_PASSWORD_FILE"
fi
