#!/usr/bin/env bash

echo "Setting up directories..."
DEPLOY_DIR="$HOME/ignition"
SCRIPT_DIR=$(dirname "$(realpath "$0")")
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
mkdir -p "$DEPLOY_DIR"
