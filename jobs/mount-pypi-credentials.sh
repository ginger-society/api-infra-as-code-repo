#!/bin/bash
set -e

# Pull netrc (used by pip for the private index)
cp /workspace/creds/.netrc ~/.netrc
chmod 600 ~/.netrc   # netrc-respecting tools (curl, python netrc module) require non-world-readable perms

cp /workspace/creds/.pypirc ~/.pypirc
chmod 600 ~/.pypirc

echo "Credentials restored from /workspace/creds for pip and netrc"