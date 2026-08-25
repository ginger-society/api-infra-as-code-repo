#!/bin/bash

# ── Args ──────────────────────────────────────────────────────────────────────
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <cluster-name> <api-port> <port-mappings-json> [--cpus N] [--memory Xg] [--disk Xg]"
    echo "Example: $0 alpha 8001 '[{\"container_port\":80,\"host_port\":8081,\"protocol\":\"TCP\"}]' --cpus 4 --memory 8g --disk 50g"
    exit 1
fi

CLUSTER_NAME="$1"
API_PORT="$2"
PORT_MAPPINGS_JSON="$3"
shift 3

# ── Optional resource limits (defaults) ───────────────────────────────────────
CPUS="2"
MEMORY="4g"
DISK="30g"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cpus)   CPUS="$2";   shift 2 ;;
        --memory) MEMORY="$2"; shift 2 ;;
        --disk)   DISK="$2";   shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

FQDN="${CLUSTER_NAME}.test-clusters.rackmint.com"
KIND_CONFIG="/tmp/kind-${CLUSTER_NAME}.yaml"
NGINX_ENTRIES_FILE="/etc/nginx/stream.d/kind-cluster-entries.map"
NGINX_STREAM_CONF="/etc/nginx/stream.d/kind-clusters.conf"

# ── Pinned node image ──────────────────────────────────────────────────────────
# Bump this deliberately when you want a k8s version upgrade — never let
# `kind create cluster` decide on its own, since an implicit image pull adds
# a multi-hundred-MB network fetch directly into cluster-creation latency.
KIND_NODE_IMAGE="kindest/node:v1.29.2@sha256:51a1434a5397193442f0be2a297b488b6c919ce8a3931be0ce822606ea5ca245"

echo "Resource limits — CPUs: ${CPUS} | Memory: ${MEMORY} | Disk: ${DISK}"
echo "Node image — ${KIND_NODE_IMAGE}"

# ── Check jq is available ─────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
    apt-get install -y jq -q
fi

# ── Check if cluster already exists ───────────────────────────────────────────
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "ERROR: cluster '${CLUSTER_NAME}' already exists"
    exit 2
fi

# ── Ensure the pinned node image is already local before creating anything ────
# Only pays a real cost the first time this ever runs on a box (or after a
# deliberate KIND_NODE_IMAGE bump) — every cluster creation after that is
# 100% local, no network round-trip in the hot path.
if ! docker image inspect "$KIND_NODE_IMAGE" &>/dev/null; then
    echo "Pinned image not cached locally, pulling once (one-time cost)..."
    docker pull "$KIND_NODE_IMAGE"
    if [ $? -ne 0 ]; then
        echo "ERROR: failed to pull pinned node image ${KIND_NODE_IMAGE}"
        exit 6
    fi
fi

# ── Build extraPortMappings yaml ──────────────────────────────────────────────
PORT_MAPPINGS_YAML=""
while IFS= read -r mapping; do
    container_port=$(echo "$mapping" | jq -r '.container_port')
    host_port=$(echo "$mapping" | jq -r '.host_port')
    protocol=$(echo "$mapping" | jq -r '.protocol // "TCP"')
    PORT_MAPPINGS_YAML="${PORT_MAPPINGS_YAML}  - containerPort: ${container_port}
    hostPort: ${host_port}
    protocol: ${protocol}
"
done < <(echo "$PORT_MAPPINGS_JSON" | jq -c '.[]')

# ── Allocate + format + mount the per-cluster disk image FIRST ───────────────
# This has to happen before `kind create cluster` runs, because the mount
# point needs to already exist and be a real filesystem before we can point
# the node's extraMounts at it — kind bind-mounts hostPath into the node
# container at creation time, it doesn't pick up a mount that shows up later.
DISK_GB=$(echo "$DISK" | sed 's/[gG]$//')
LOOP_IMAGE_DIR="/var/kind-disks"
LOOP_IMAGE="${LOOP_IMAGE_DIR}/${CLUSTER_NAME}.img"
MOUNT_POINT="/var/kind-mounts/${CLUSTER_NAME}"

mkdir -p "$LOOP_IMAGE_DIR" "$MOUNT_POINT"

echo "Allocating ${DISK_GB}GB disk image for cluster '${CLUSTER_NAME}'..."
fallocate -l "${DISK_GB}G" "$LOOP_IMAGE"
if [ $? -ne 0 ]; then
    echo "WARNING: fallocate failed, trying dd fallback..."
    dd if=/dev/zero of="$LOOP_IMAGE" bs=1G count="${DISK_GB}" status=progress
fi

mkfs.ext4 -F "$LOOP_IMAGE"

LOOP_DEV=$(losetup --find --show "$LOOP_IMAGE")
mount "$LOOP_DEV" "$MOUNT_POINT"

DISK_MOUNTED=0
if [ $? -ne 0 ]; then
    echo "WARNING: failed to mount disk image — cluster will be created WITHOUT a disk limit or per-cluster disk isolation"
else
    DISK_MOUNTED=1

    # Give the node's future containerd/kubelet dirs their own subdirs on the
    # mounted volume, so extraMounts below has somewhere real to bind to.
    mkdir -p "${MOUNT_POINT}/containerd" "${MOUNT_POINT}/kubelet"

    # Persist mount across reboots
    echo "${LOOP_DEV} ${MOUNT_POINT} ext4 defaults,nofail 0 0" >> /etc/fstab

    # Store metadata so delete script can clean this up
    echo "LOOP_DEV=${LOOP_DEV}" > "${LOOP_IMAGE_DIR}/${CLUSTER_NAME}.meta"
    echo "LOOP_IMAGE=${LOOP_IMAGE}" >> "${LOOP_IMAGE_DIR}/${CLUSTER_NAME}.meta"
    echo "MOUNT_POINT=${MOUNT_POINT}" >> "${LOOP_IMAGE_DIR}/${CLUSTER_NAME}.meta"

    echo "✅ Disk limit of ${DISK_GB}GB allocated at ${MOUNT_POINT}"
fi

# ── Write Kind config ─────────────────────────────────────────────────────────
# extraMounts only gets added if the disk actually mounted — falling back to
# default in-container storage (untracked, unlimited) rather than pointing
# at a hostPath that doesn't exist, which would fail cluster creation outright.
EXTRA_MOUNTS_YAML=""
if [ "$DISK_MOUNTED" -eq 1 ]; then
    EXTRA_MOUNTS_YAML="  extraMounts:
  - hostPath: ${MOUNT_POINT}/containerd
    containerPath: /var/lib/containerd
  - hostPath: ${MOUNT_POINT}/kubelet
    containerPath: /var/lib/kubelet
"
fi

cat > "$KIND_CONFIG" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}

networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: ${API_PORT}

nodes:
- role: control-plane
  image: ${KIND_NODE_IMAGE}
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      certSANs:
      - ${FQDN}
      - 127.0.0.1
      - localhost
${EXTRA_MOUNTS_YAML}  extraPortMappings:
${PORT_MAPPINGS_YAML}
EOF

# ── Create cluster ────────────────────────────────────────────────────────────
echo "Creating kind cluster '${CLUSTER_NAME}'..."
kind create cluster --config "$KIND_CONFIG"
if [ $? -ne 0 ]; then
    echo "ERROR: kind create cluster failed"
    rm -f "$KIND_CONFIG"
    exit 3
fi

rm -f "$KIND_CONFIG"

# ── Apply CPU and memory limits ───────────────────────────────────────────────
echo "Applying resource limits to '${CLUSTER_NAME}-control-plane'..."
docker update \
    --cpus "${CPUS}" \
    --memory "${MEMORY}" \
    --memory-swap "${MEMORY}" \
    "${CLUSTER_NAME}-control-plane"

if [ $? -ne 0 ]; then
    echo "WARNING: failed to apply CPU/memory limits (non-fatal, cluster still usable)"
else
    echo "✅ CPU and memory limits applied"
fi

# ── Update Nginx stream config ────────────────────────────────────────────────
mkdir -p /etc/nginx/stream.d

touch "$NGINX_ENTRIES_FILE"
sed -i "/^.*${FQDN}.*$/d" "$NGINX_ENTRIES_FILE"
echo "        ${FQDN}    127.0.0.1:${API_PORT};" >> "$NGINX_ENTRIES_FILE"

cat > "$NGINX_STREAM_CONF" <<EOF
map \$ssl_preread_server_name \$kind_backend {
$(cat "$NGINX_ENTRIES_FILE")
}

server {
    listen 3333;
    ssl_preread on;
    proxy_pass \$kind_backend;
}
EOF

nginx -t && systemctl reload nginx
if [ $? -ne 0 ]; then
    echo "ERROR: nginx reload failed"
    exit 4
fi

# ── Get kubeconfig and replace server hostname ────────────────────────────────
KUBECONFIG=$(kind get kubeconfig --name "${CLUSTER_NAME}" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "ERROR: failed to get kubeconfig"
    exit 5
fi

KUBECONFIG=$(echo "$KUBECONFIG" | sed "s|server: https://0\.0\.0\.0:${API_PORT}|server: https://${FQDN}:3333|g")
KUBECONFIG=$(echo "$KUBECONFIG" | sed "s|server: https://127\.0\.0\.1:${API_PORT}|server: https://${FQDN}:3333|g")

echo "KUBECONFIG_START"
echo "$KUBECONFIG"
echo "KUBECONFIG_END"

# ── Save kubeconfig ───────────────────────────────────────────────────────────
KUBE_DIR="${HOME}/.kube"
mkdir -p "$KUBE_DIR"

echo "$KUBECONFIG" > "${KUBE_DIR}/${CLUSTER_NAME}.yaml"
chmod 600 "${KUBE_DIR}/${CLUSTER_NAME}.yaml"

echo "Kubeconfig saved to ${KUBE_DIR}/${CLUSTER_NAME}.yaml"
echo "Use it with: kubectl --kubeconfig=${KUBE_DIR}/${CLUSTER_NAME}.yaml get nodes"
echo "Or export:   export KUBECONFIG=${KUBE_DIR}/${CLUSTER_NAME}.yaml"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "✅ Cluster '${CLUSTER_NAME}' ready"
echo "   CPUs:   ${CPUS}"
echo "   Memory: ${MEMORY}"
if [ "$DISK_MOUNTED" -eq 1 ]; then
    echo "   Disk:   ${DISK_GB}GB (${MOUNT_POINT}) — bind-mounted to node's containerd + kubelet storage"
else
    echo "   Disk:   ${DISK_GB}GB requested but NOT applied (mount failed) — node using default unlimited storage"
fi
echo "   Image:  ${KIND_NODE_IMAGE}"
echo "   FQDN:   ${FQDN}"