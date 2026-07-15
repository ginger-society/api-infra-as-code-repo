#!/usr/bin/env sh
#
# upload-single-env-file.sh
#
# Uploads a single file to the env-files API, using the file's own
# basename as the file_name.
#
# Usage:
#   ./upload-single-env-file.sh <file_path> <environment> <workspace>
#
# Example:
#   ./upload-single-env-file.sh ./artifactory.yaml production ginger-society
#   ./upload-single-env-file.sh ~/Downloads/kubeconfig/gingersociety.yaml production ginger-society

set -eu

FILE_PATH="${1:-}"
ENVIRONMENT="${2:-}"
WORKSPACE="${3:-}"

AUTH_FILE="${HOME}/.ginger-society/auth.json"
API_URL="https://source.gingersociety.org/env-files"

if [ -z "$FILE_PATH" ] || [ -z "$ENVIRONMENT" ] || [ -z "$WORKSPACE" ]; then
  echo "Usage: $0 <file_path> <environment> <workspace>" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }

if [ ! -f "$FILE_PATH" ]; then
  echo "Error: file '$FILE_PATH' not found." >&2
  exit 1
fi

if [ ! -f "$AUTH_FILE" ]; then
  echo "Error: auth file '$AUTH_FILE' not found." >&2
  exit 1
fi

API_TOKEN=$(jq -r '.API_TOKEN // empty' "$AUTH_FILE")
if [ -z "$API_TOKEN" ]; then
  echo "Error: could not read API_TOKEN from $AUTH_FILE" >&2
  exit 1
fi

FILE_NAME=$(basename "$FILE_PATH")

PAYLOAD=$(jq -n \
  --arg environment "$ENVIRONMENT" \
  --arg workspace "$WORKSPACE" \
  --arg file_name "$FILE_NAME" \
  --rawfile file_content "$FILE_PATH" \
  '{environment: $environment, workspace: $workspace, file_name: $file_name, file_content: $file_content}')

echo "Uploading '$FILE_NAME' (from $FILE_PATH) for environment='$ENVIRONMENT' workspace='$WORKSPACE'..."

TMP_RESPONSE=$(mktemp)
trap 'rm -f "$TMP_RESPONSE"' EXIT

HTTP_STATUS=$(curl -s -o "$TMP_RESPONSE" -w '%{http_code}' \
  -X POST "$API_URL" \
  -H 'accept: application/json' \
  -H "X-API-Authorization: ${API_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD")

case "$HTTP_STATUS" in
  2*)
    echo "✓ Uploaded '$FILE_NAME' (HTTP $HTTP_STATUS)"
    ;;
  *)
    echo "✗ Failed to upload '$FILE_NAME' (HTTP $HTTP_STATUS)"
    echo "  Response: $(cat "$TMP_RESPONSE" 2>/dev/null)"
    exit 1
    ;;
esac