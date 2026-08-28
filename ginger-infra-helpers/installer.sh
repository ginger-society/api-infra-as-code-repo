#!/bin/bash

# ── Root check ────────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# ── OS guard ──────────────────────────────────────────────────────────────────
OS_TYPE=""
case "$(uname -s)" in
    Linux)
        OS_TYPE="linux"
        ;;
    Darwin)
        OS_TYPE="darwin"
        ;;
    CYGWIN*|MINGW32*|MSYS*|MINGW*)
        echo "❌ Windows is not supported. Exiting."
        exit 1
        ;;
    *)
        echo "❌ Unsupported OS. Exiting."
        exit 1
        ;;
esac

# ── Argument parsing ──────────────────────────────────────────────────────────
DEVICE_ID=""
INSTALL_GATEWAY=false
INSTALL_K8_CLUSTER_MANAGER=false
AWS_ACCESS_KEY_ID_ARG=""
AWS_SECRET_ACCESS_KEY_ARG=""
AWS_REGION_ARG=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --device-id)
            DEVICE_ID="$2"
            shift 2
            ;;
        --install-gateway)
            INSTALL_GATEWAY=true
            shift
            ;;
        --install-k8-cluster-manager)
            INSTALL_K8_CLUSTER_MANAGER=true
            shift
            ;;
        --aws-access-key-id)
            AWS_ACCESS_KEY_ID_ARG="$2"
            shift 2
            ;;
        --aws-secret-access-key)
            AWS_SECRET_ACCESS_KEY_ARG="$2"
            shift 2
            ;;
        --aws-region)
            AWS_REGION_ARG="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: curl -fsSL <url> | bash -s -- --device-id <device-id> [--install-gateway] [--aws-access-key-id <id> --aws-secret-access-key <key> [--aws-region <region>]] [--install-k8-cluster-manager]"
            exit 1
            ;;
    esac
done

if [ -z "$DEVICE_ID" ]; then
    echo "Usage: curl -fsSL <url> | bash -s -- --device-id <device-id> [--install-gateway]"
    echo "Example: curl -fsSL <url> | bash -s -- --device-id my-server --install-gateway"
    exit 1
fi

# ── Gateway on macOS guard ────────────────────────────────────────────────────
if [ "$INSTALL_GATEWAY" = true ] && [ "$OS_TYPE" = "darwin" ]; then
    echo "❌ --install-gateway is only supported on Linux."
    exit 1
fi

if [ "$INSTALL_K8_CLUSTER_MANAGER" = true ] && [ "$OS_TYPE" = "darwin" ]; then
    echo "❌ --install-k8-cluster-manager is only supported on Linux."
    exit 1
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
is_installed() {
    command -v "$1" &>/dev/null
}

apt_install_if_missing() {
    local pkg="$1"
    local cmd="${2:-$1}"
    if is_installed "$cmd"; then
        echo "✅ $pkg already installed, skipping."
    else
        echo "📦 Installing $pkg..."
        apt-get install -y "$pkg"
        echo "✅ $pkg installed."
    fi
}

confirm() {
    read -r -p "$1 [y/N] " response </dev/tty
    [[ "$response" =~ ^[Yy]$ ]]
}

# ── Stop and remove existing ginger-infra ────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Cleaning up existing ginger-infra installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$OS_TYPE" = "linux" ]; then
    if systemctl is-active --quiet ginger-infra 2>/dev/null; then
        echo "Stopping ginger-infra service..."
        systemctl stop ginger-infra
    fi
elif [ "$OS_TYPE" = "darwin" ]; then
    PLIST="/Library/LaunchDaemons/org.gingersociety.ginger-infra.plist"
    if [ -f "$PLIST" ]; then
        echo "Stopping ginger-infra daemon..."
        launchctl unload "$PLIST" 2>/dev/null
    fi
fi

if [ -f "/usr/local/bin/ginger-infra" ]; then
    echo "Removing existing binary..."
    rm -f /usr/local/bin/ginger-infra
    echo "✅ Old binary removed."
else
    echo "No existing binary found, skipping."
fi


# ── Install ginger-infra binary ───────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Installing ginger-infra"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

bash -c "$(curl -fsSL https://raw.githubusercontent.com/ginger-society/infra-as-code-repo/main/rust-helpers/installer.sh)" -- ginger-society/ginger-infra:latest

if [ $? -ne 0 ]; then
    echo "❌ Failed to install ginger-infra"
    exit 1
fi

BINARY="/usr/local/bin/ginger-infra"
CONFIG_DIR="/etc/ginger-infra"
mkdir -p "$CONFIG_DIR"

# ── Set up daemon ─────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Setting up daemon"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$OS_TYPE" = "darwin" ]; then
    PLIST="/Library/LaunchDaemons/org.gingersociety.ginger-infra.plist"

    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>org.gingersociety.ginger-infra</string>

    <key>ProgramArguments</key>
    <array>
        <string>${BINARY}</string>
        <string>start</string>
        <string>--device-id</string>
        <string>${DEVICE_ID}</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/var/log/ginger-infra.log</string>

    <key>StandardErrorPath</key>
    <string>/var/log/ginger-infra.error.log</string>

    <key>WorkingDirectory</key>
    <string>/etc/ginger-infra</string>
</dict>
</plist>
EOF

    chown root:wheel "$PLIST"
    chmod 644 "$PLIST"
    launchctl unload "$PLIST" 2>/dev/null
    launchctl load -w "$PLIST"

    echo "✅ ginger-infra daemon installed and started via launchd"
    echo "   Device ID: ${DEVICE_ID}"
    echo "   Logs:      /var/log/ginger-infra.log"
    echo "   To stop:   sudo launchctl unload $PLIST"
    echo "   To start:  sudo launchctl load $PLIST"

elif [ "$OS_TYPE" = "linux" ]; then
    SERVICE="/etc/systemd/system/ginger-infra.service"

    cat > "$SERVICE" <<EOF
[Unit]
Description=Ginger Infra Daemon
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BINARY} start --device-id ${DEVICE_ID}
Restart=always
RestartSec=5
WorkingDirectory=/etc/ginger-infra
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ginger-infra

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ginger-infra
    systemctl restart ginger-infra

    echo "✅ ginger-infra daemon installed and started via systemd"
    echo "   Device ID: ${DEVICE_ID}"
    echo "   Logs:      sudo journalctl -u ginger-infra -f"
    echo "   To stop:   sudo systemctl stop ginger-infra"
    echo "   To start:  sudo systemctl start ginger-infra"
    echo "   Status:    sudo systemctl status ginger-infra"
fi

# ── Gateway installation ──────────────────────────────────────────────────────
if [ "$INSTALL_GATEWAY" = false ]; then
    echo ""
    echo "✅ Done. Run with --install-gateway to also set up Apache2, Snap, Certbot and Nginx."
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Gateway Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This will install and configure the following:"
echo "  • Snap"
echo "  • Certbot (via Snap) + certbot-dns-route53 plugin"
echo "  • Apache2 with modules: ssl, proxy, proxy_http, proxy_wstunnel, rewrite, headers, proxy_connect"
echo "  • Nginx (configured to NOT listen on 80/443 — Apache2 is the main gateway)"
echo ""

if ! confirm "Proceed with gateway installation?"; then
    echo "Skipping gateway installation."
    exit 0
fi

# ── Route53 credentials for certbot dns-route53 ──────────────────────────────
#
# install_ssl (in ginger-infra) shells out to `certbot --authenticator
# dns-route53` to issue wildcard certs for domains whose DNS now lives in
# Route53 (see api/dns.rs hosted-zone flow). certbot-dns-route53 reads
# these via the standard AWS SDK env-var credential chain — no
# credentials-file flag, unlike the old dns-godaddy setup.
#
# Written to its own root-only file rather than embedded in the unit file,
# since unit files are commonly world-readable (0644) and get dumped by
# `systemctl cat` / bug-report tooling.
AWS_ENV_FILE="/etc/ginger-infra/aws-credentials.env"

echo ""
echo "── AWS credentials (for certbot Route53 DNS challenges) ──"

# If the env file already exists, load its current values as fallbacks so
# a re-run doesn't re-prompt (or silently blank out) credentials that are
# already in place — only genuinely missing pieces get asked for.
if [ -f "$AWS_ENV_FILE" ]; then
    EXISTING_AWS_ACCESS_KEY_ID=$(grep -E '^AWS_ACCESS_KEY_ID=' "$AWS_ENV_FILE" | cut -d= -f2-)
    EXISTING_AWS_SECRET_ACCESS_KEY=$(grep -E '^AWS_SECRET_ACCESS_KEY=' "$AWS_ENV_FILE" | cut -d= -f2-)
    EXISTING_AWS_REGION=$(grep -E '^AWS_REGION=' "$AWS_ENV_FILE" | cut -d= -f2-)

    AWS_ACCESS_KEY_ID_ARG="${AWS_ACCESS_KEY_ID_ARG:-$EXISTING_AWS_ACCESS_KEY_ID}"
    AWS_SECRET_ACCESS_KEY_ARG="${AWS_SECRET_ACCESS_KEY_ARG:-$EXISTING_AWS_SECRET_ACCESS_KEY}"
    AWS_REGION_ARG="${AWS_REGION_ARG:-$EXISTING_AWS_REGION}"

    if [ -n "$EXISTING_AWS_ACCESS_KEY_ID" ] && [ -n "$EXISTING_AWS_SECRET_ACCESS_KEY" ]; then
        echo "✅ Existing AWS credentials found at ${AWS_ENV_FILE}, reusing them."
    fi
fi

if [ -z "$AWS_ACCESS_KEY_ID_ARG" ]; then
    read -r -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID_ARG </dev/tty
fi

if [ -z "$AWS_SECRET_ACCESS_KEY_ARG" ]; then
    read -r -s -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY_ARG </dev/tty
    echo ""
fi

if [ -z "$AWS_ACCESS_KEY_ID_ARG" ] || [ -z "$AWS_SECRET_ACCESS_KEY_ARG" ]; then
    echo "❌ AWS credentials are required for Route53 DNS challenges (certbot uses these to issue wildcard certs)."
    exit 1
fi

AWS_REGION_ARG="${AWS_REGION_ARG:-us-east-1}"

# Only rewrite the file if something actually changed — avoids an
# unnecessary mtime bump / restart trigger on a no-op re-run.
NEW_AWS_ENV_CONTENT="AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID_ARG}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY_ARG}
AWS_REGION=${AWS_REGION_ARG}"

if [ -f "$AWS_ENV_FILE" ] && [ "$(cat "$AWS_ENV_FILE")" = "$NEW_AWS_ENV_CONTENT" ]; then
    echo "✅ AWS credentials unchanged, ${AWS_ENV_FILE} left as-is."
else
    echo "$NEW_AWS_ENV_CONTENT" > "$AWS_ENV_FILE"
    chmod 600 "$AWS_ENV_FILE"
    chown root:root "$AWS_ENV_FILE"
    echo "✅ AWS credentials written to ${AWS_ENV_FILE} (0600, root-only)"
fi

# ── Wire AWS credentials into the ginger-infra unit and restart ─────────────
SERVICE="/etc/systemd/system/ginger-infra.service"

if [ -f "$SERVICE" ] && ! grep -q "^EnvironmentFile=${AWS_ENV_FILE}" "$SERVICE"; then
    sed -i "/^ExecStart=/a EnvironmentFile=${AWS_ENV_FILE}" "$SERVICE"
    echo "✅ Linked ${AWS_ENV_FILE} into ginger-infra.service"
fi

systemctl daemon-reload
systemctl restart ginger-infra
echo "✅ ginger-infra restarted with AWS credentials loaded"

apt-get update -y

# ── Snap ──────────────────────────────────────────────────────────────────────
echo ""
echo "── Snap ─────────────────────────────────────────────────"

# ensure universe repo is enabled (required for snapd on GCP Ubuntu)
apt-get install -y software-properties-common
add-apt-repository -y universe
apt-get update -y

apt_install_if_missing "snapd" "snap"

systemctl enable --now snapd.socket

# ensure snap core is up to date
snap install core 2>/dev/null
snap refresh core 2>/dev/null

# ── Certbot ───────────────────────────────────────────────────────────────────
echo ""
echo "── Certbot ──────────────────────────────────────────────"
if snap list certbot &>/dev/null; then
    echo "✅ certbot already installed via snap, skipping."
else
    echo "📦 Installing certbot via snap..."
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
    echo "✅ certbot installed."
fi

# ── Certbot Route53 plugin ────────────────────────────────────────────────────
echo ""
echo "── Certbot Route53 DNS plugin ──────────────────────────"
if snap list certbot-dns-route53 &>/dev/null; then
    echo "✅ certbot-dns-route53 already installed, skipping."
else
    echo "📦 Installing certbot-dns-route53 plugin..."
    snap install certbot-dns-route53
    snap set certbot trust-plugin-with-root=ok
    snap connect certbot:plugin certbot-dns-route53
    echo "✅ certbot-dns-route53 installed and connected."
fi

# ── Apache2 ───────────────────────────────────────────────────────────────────
echo ""
echo "── Apache2 ──────────────────────────────────────────────"
apt_install_if_missing "apache2" "apache2"

echo "🔧 Enabling Apache2 modules..."

APACHE_MODULES=(
    ssl
    proxy
    proxy_http
    proxy_wstunnel
    rewrite
    headers
    proxy_connect
)

for mod in "${APACHE_MODULES[@]}"; do
    if apache2ctl -M 2>/dev/null | grep -q "${mod}_module"; then
        echo "✅ mod_${mod} already enabled, skipping."
    else
        echo "  enabling mod_${mod}..."
        a2enmod "$mod"
    fi
done

# ── Nginx ─────────────────────────────────────────────────────────────────────
echo ""
echo "── Nginx ────────────────────────────────────────────────"
apt_install_if_missing "nginx" "nginx"

echo "🔧 Configuring Nginx to not listen on 80/443 (Apache2 is the gateway)..."

NGINX_DEFAULT="/etc/nginx/sites-enabled/default"

# disable the default site if present
if [ -f "$NGINX_DEFAULT" ]; then
    rm -f "$NGINX_DEFAULT"
    echo "   removed default nginx site"
fi

# write a safe fallback config that doesn't bind 80/443
cat > /etc/nginx/sites-available/ginger-infra-passthrough <<'EOF'
# Nginx managed by ginger-infra installer
# Apache2 handles 80 and 443 — Nginx is available for internal use only
# Add your internal upstreams here if needed
EOF

echo "✅ Nginx configured — not binding on 80/443."

# ── Restart services ──────────────────────────────────────────────────────────
echo ""
echo "── Restarting services ──────────────────────────────────"

systemctl restart apache2
if [ $? -eq 0 ]; then
    echo "✅ Apache2 restarted."
else
    echo "⚠️  Apache2 failed to restart — check: sudo journalctl -u apache2"
fi

systemctl restart nginx
if [ $? -eq 0 ]; then
    echo "✅ Nginx restarted."
else
    echo "⚠️  Nginx failed to restart — check: sudo journalctl -u nginx"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Gateway installation complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Apache2 status:     sudo service apache2 status"
echo "  Apache2 logs:       /var/log/apache2/"
echo "  AWS creds file:     ${AWS_ENV_FILE}"


# ── K8 Cluster Manager installation ──────────────────────────────────────────
if [ "$INSTALL_K8_CLUSTER_MANAGER" = true ]; then

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " K8 Cluster Manager Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This will install and configure the following:"
echo "  • Docker"
echo "  • Kind (Kubernetes in Docker)"
echo "  • kubectl"
echo ""

if ! confirm "Proceed with K8 cluster manager installation?"; then
    echo "Skipping K8 cluster manager installation."
else
    apt-get update -y

    # ── Docker ────────────────────────────────────────────────────────────────────
    echo ""
    echo "── Docker ───────────────────────────────────────────────"
    if is_installed "docker"; then
        echo "✅ Docker already installed, skipping."
    else
        echo "📦 Installing Docker..."
        apt-get install -y ca-certificates curl gnupg lsb-release

        install -m 0755 -d /etc/apt/keyrings

        # detect debian vs ubuntu for correct repo
        DISTRO_ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
        DISTRO_CODENAME=$(lsb_release -cs)

        if [ "$DISTRO_ID" = "debian" ]; then
            DOCKER_REPO="https://download.docker.com/linux/debian"
        else
            DOCKER_REPO="https://download.docker.com/linux/ubuntu"
        fi

        curl -fsSL "${DOCKER_REPO}/gpg" | \
            gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
            ${DOCKER_REPO} \
            ${DISTRO_CODENAME} stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        systemctl enable docker
        systemctl start docker

        echo "✅ Docker installed."
    fi

    # ── kubectl ───────────────────────────────────────────────────────────────
    echo ""
    echo "── kubectl ──────────────────────────────────────────────"
    if is_installed "kubectl"; then
        echo "✅ kubectl already installed, skipping."
    else
        echo "📦 Installing kubectl..."
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
            gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
            https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | \
            tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

        apt-get update -y
        apt-get install -y kubectl
        echo "✅ kubectl installed."
    fi

    # ── Kind ──────────────────────────────────────────────────────────────────
    echo ""
    echo "── Kind ─────────────────────────────────────────────────"
    if is_installed "kind"; then
        echo "✅ Kind already installed, skipping."
    else
        echo "📦 Installing Kind..."
        ARCH=$(dpkg --print-architecture)
        curl -Lo /usr/local/bin/kind \
            "https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-${ARCH}"
        chmod +x /usr/local/bin/kind
        echo "✅ Kind installed."
    fi

    # ── Summary ───────────────────────────────────────────────────────────────
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ K8 cluster manager installation complete"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""
    echo "  Docker status:  sudo systemctl status docker"
fi

fi