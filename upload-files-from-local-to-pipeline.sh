#!/usr/bin/env sh
set -eu

CONFIG_FILE="${1:-}"
ENVIRONMENT="${2:-}"
WORKSPACE="${3:-}"
VAULT_FILE="${4:-./vault.json}"

AUTH_FILE="${HOME}/.ginger-society/auth.json"
API_URL="https://source.gingersociety.org/env-files"

if [ -z "$CONFIG_FILE" ] || [ -z "$ENVIRONMENT" ] || [ -z "$WORKSPACE" ]; then
  echo "Usage: $0 <config.json> <environment> <workspace> [vault_file]" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
[ -f "$CONFIG_FILE" ] || { echo "Config file not found: $CONFIG_FILE" >&2; exit 1; }
[ -f "$AUTH_FILE" ] || { echo "Auth file not found: $AUTH_FILE" >&2; exit 1; }

API_TOKEN=$(jq -r '.API_TOKEN // empty' "$AUTH_FILE")
[ -n "$API_TOKEN" ] || { echo "Could not read API_TOKEN" >&2; exit 1; }

TMP_LIST=$(mktemp)
trap 'rm -f "$TMP_LIST" /tmp/env-upload-response.json' EXIT

FAILED=0

# ---------- Reusable upload function ----------
# Usage: upload_file <local_path> <remote_file_name>
upload_file() {
  LOCAL_PATH="$1"
  FILE_NAME="$2"

  if [ ! -f "$LOCAL_PATH" ]; then
    echo "✗ Skipping: '$LOCAL_PATH' does not exist relative to $(pwd)"
    FAILED=1
    return
  fi

  PAYLOAD=$(jq -n \
    --arg environment "$ENVIRONMENT" \
    --arg workspace "$WORKSPACE" \
    --arg file_name "$FILE_NAME" \
    --rawfile file_content "$LOCAL_PATH" \
    '{environment: $environment, workspace: $workspace, file_name: $file_name, file_content: $file_content}')

  echo "Uploading '$FILE_NAME' (from $LOCAL_PATH)..."

  HTTP_STATUS=$(curl -s -o /tmp/env-upload-response.json -w '%{http_code}' \
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
      echo "  Response: $(cat /tmp/env-upload-response.json 2>/dev/null)"
      FAILED=1
      ;;
  esac
  echo
}

# ---------- Upload files referenced via file(...) in config ----------

grep -oE 'file\([^)]*\)' "$CONFIG_FILE" \
  | sed -E 's/^file\((.*)\)$/\1/' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
  | sort -u > "$TMP_LIST"

if [ -s "$TMP_LIST" ]; then
  echo "Files to upload for environment='$ENVIRONMENT' workspace='$WORKSPACE':"
  cat "$TMP_LIST"
  echo

  while IFS= read -r RAW_PATH; do
    upload_file "$RAW_PATH" "$(basename "$RAW_PATH")"
  done < "$TMP_LIST"
else
  echo "No file(...) references found in $CONFIG_FILE"
fi

# ---------- Upload vault.json ----------

upload_file "$VAULT_FILE" "vault.json"

# ---------- Summary ----------

if [ "$FAILED" -ne 0 ]; then
  echo "One or more uploads failed." >&2
  exit 1
fi

echo "All files uploaded successfully."