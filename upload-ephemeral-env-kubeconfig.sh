#!/usr/bin/env bash

set -euo pipefail

#
# upload-ephemeral-env-kubeconfig.sh
#
# Uploads a kubeconfig for an ephemeral environment.
#
# Usage:
#   ./upload-ephemeral-env-kubeconfig.sh <workspace-id> <branch> <kubeconfig-path>
#
# Example:
#   ./upload-ephemeral-env-kubeconfig.sh ginger-society main ~/.kube/config
#
# Requirements:
#   - curl
#   - jq
#
# Auth:
#   Reads the API token from:
#     ~/.ginger-society/auth.json
#
# Expected auth.json format:
# {
#   "API_TOKEN": "eyJhbGciOi..."
# }

if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 <workspace-id> <branch> <kubeconfig-path>"
    exit 1
fi

WORKSPACE_ID="$1"
BRANCH="$2"
KUBECONFIG_PATH="$3"

AUTH_FILE="$HOME/.ginger-society/auth.json"

if [ ! -f "$AUTH_FILE" ]; then
    echo "Auth file not found: $AUTH_FILE"
    exit 1
fi

if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "Kubeconfig not found: $KUBECONFIG_PATH"
    exit 1
fi

TOKEN=$(jq -r '.API_TOKEN' "$AUTH_FILE")

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "API_TOKEN not found in $AUTH_FILE"
    exit 1
fi

BODY=$(jq -Rs '{kubeconfig: .}' < "$KUBECONFIG_PATH")

curl \
    --fail \
    --show-error \
    --silent \
    -X POST \
    "https://source.gingersociety.org/ephemeral-env-kubeconfig/${WORKSPACE_ID}/${BRANCH}" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -H "X-API-Authorization: ${TOKEN}" \
    -d "$BODY"

echo