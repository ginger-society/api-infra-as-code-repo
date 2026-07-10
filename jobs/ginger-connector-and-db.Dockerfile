FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    libssl1.1 \
    libpq5 \
    libgcc1 \
    libc6 \
    libssl-dev \
    ca-certificates \
    curl \
    gnupg \
    default-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 22 & Package Managers ────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── OpenAPI Generator CLI + pre-download JAR ─────────────────────────────────
RUN npm install -g @openapitools/openapi-generator-cli \
    && openapi-generator-cli version-manager set 7.12.0 \
    && openapi-generator-cli version

RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ginger-society/infra-as-code-repo/main/rust-helpers/installer.sh)" -- ginger-society/ginger-connector:latest
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ginger-society/infra-as-code-repo/main/rust-helpers/installer.sh)" -- ginger-society/ginger-db:latest

# Copy setup script
COPY copy-credentials-to-workspace.sh /usr/local/bin/copy-credentials-to-workspace.sh
RUN chmod +x /usr/local/bin/copy-credentials-to-workspace.sh