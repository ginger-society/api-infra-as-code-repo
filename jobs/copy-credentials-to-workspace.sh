#!/bin/bash
set -e

# ginger-auth token-login writes to ~/.ssh/ and ~/.ginger-society/
ginger-auth token-login $GINGER_TOKEN

# Copy everything ginger-auth generated into the shared creds workspace.
# IMPORTANT: files in the workspace are read by other containers (the runner
# step) which may run as a different user. Set permissions explicitly:
#   - Private key: 644 (not 600) so other users can read it.
#     The runner copies it to its own ~/.ssh/ and sets 600 there.
#     A 600 file owned by a different UID is unreadable by the runner.
#   - Everything else: 644 (standard readable).
mkdir -p /workspace/creds/ssh

cp ~/.ssh/id_ed25519           /workspace/creds/ssh/id_ed25519
cp ~/.ssh/id_ed25519.pub       /workspace/creds/ssh/id_ed25519.pub
cp ~/.ssh/id_ed25519-cert.pub  /workspace/creds/ssh/id_ed25519-cert.pub

# Make all ssh files world-readable so the runner container user can read them.
# The runner sets 600 on the private key after copying it to its own ~/.ssh/.
chmod 644 /workspace/creds/ssh/id_ed25519
chmod 644 /workspace/creds/ssh/id_ed25519.pub
chmod 644 /workspace/creds/ssh/id_ed25519-cert.pub

# auth.json for ginger-connector
mkdir -p /workspace/creds/ginger-society
cp ~/.ginger-society/auth.json  /workspace/creds/ginger-society/auth.json
chmod 644 /workspace/creds/ginger-society/auth.json

# docker config written by ginger-auth
mkdir -p /workspace/creds/docker
cp ~/.docker/config.json        /workspace/creds/docker/config.json
chmod 644 /workspace/creds/docker/config.json

# npmrc and pypirc if your pipeline needs them
cp ~/.npmrc   /workspace/creds/.npmrc
cp ~/.pypirc  /workspace/creds/.pypirc
cp ~/.netrc  /workspace/creds/.netrc
chmod 644 /workspace/creds/.npmrc
chmod 644 /workspace/creds/.pypirc
chmod 644 /workspace/creds/.netrc

echo "Credentials written to /workspace/creds"