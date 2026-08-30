#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

CLUSTER_NAME="$1"
FQDN="${CLUSTER_NAME}.test-clusters.rackmint.com"
NGINX_ENTRIES_FILE="/etc/nginx/stream.d/kind-cluster-entries.map"
NGINX_STREAM_CONF="/etc/nginx/stream.d/kind-clusters.conf"

if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "ERROR: cluster '${CLUSTER_NAME}' does not exist"
    exit 2
fi

kind delete cluster --name "${CLUSTER_NAME}"
if [ $? -ne 0 ]; then
    echo "ERROR: kind delete cluster failed"
    exit 3
fi

# Remove nginx entry and rebuild conf
sed -i "/^.*${FQDN}.*$/d" "$NGINX_ENTRIES_FILE"

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

# Remove saved kubeconfig (best-effort)
rm -f "/root/.kube/${CLUSTER_NAME}.yaml"

echo "Cluster '${CLUSTER_NAME}' deleted successfully"