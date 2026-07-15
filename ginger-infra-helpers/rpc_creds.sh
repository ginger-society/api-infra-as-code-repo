#!/bin/sh
# rpc_creds.sh — sourced at the top of every remote script.
#
# Single required line in any device script:
#   source ~/.ginger-society/hooks/rpc_creds.sh
#
# After sourcing:
#   - HOME=/tmp/rpc/<RPC_JOB_ID>  (job-scoped, collision-safe)
#   - USER=rpc-runner
#   - All credentials reconstructed under $HOME
#   - Standard tools (docker, npm, git, ginger-infra) find creds at $HOME

# ── Job-scoped HOME ───────────────────────────────────────────────────────────
# RPC_JOB_ID is injected by the device agent from parsed.job_id.
# Falls back to a timestamp if somehow not set.
if [ -z "$RPC_JOB_ID" ]; then
  echo "[rpc_creds] WARNING: RPC_JOB_ID not set — falling back to timestamp" >&2
  RPC_JOB_ID="$(date +%s)"
fi

export HOME="/tmp/rpc/$RPC_JOB_ID"
export USER=rpc-runner

mkdir -p "$HOME"

# ── decode one CRED_* var to a file ──────────────────────────────────────────
_decode_cred() {
  var_name="$1"
  dest_path="$2"
  mode="$3"

  encoded=$(eval "printf '%s' \"\${${var_name}:-}\"")
  if [ -z "$encoded" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$dest_path")"
  printf '%s' "$encoded" | base64 -d > "$dest_path"
  chmod "$mode" "$dest_path"
}

# ── reconstruct under job-scoped $HOME ────────────────────────────────────────
_decode_cred CRED_AUTH_JSON     "$HOME/.ginger-society/auth.json"  644
_decode_cred CRED_SSH_KEY       "$HOME/.ssh/id_ed25519"            600
_decode_cred CRED_SSH_KEY_PUB   "$HOME/.ssh/id_ed25519.pub"        644
_decode_cred CRED_SSH_CERT      "$HOME/.ssh/id_ed25519-cert.pub"   644
_decode_cred CRED_DOCKER_CONFIG "$HOME/.docker/config.json"        644
_decode_cred CRED_NPMRC         "$HOME/.npmrc"                     644
_decode_cred CRED_PYPIRC        "$HOME/.pypirc"                    644

if [ -d "$HOME/.ssh" ]; then
  chmod 700 "$HOME/.ssh"
fi

echo "[rpc_creds] credentials ready at $HOME (job=$RPC_JOB_ID)"



# ── Docker socket (Docker Desktop runs under the logged-in GUI user,
#    not rpc-runner, so point at that user's socket explicitly) ────────────
# export DOCKER_HOST="unix:///Users/<REPLACE_ME: the desktop username>/.docker/run/docker.sock"