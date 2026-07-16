FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    libssl1.1 \
    libpq5 \
    libgcc1 \
    libc6 \
    libssl-dev \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/kubectl

# Install helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod +x get_helm.sh \
    && ./get_helm.sh \
    && rm get_helm.sh

RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ginger-society/infra-as-code-repo/main/rust-helpers/installer.sh)" -- ginger-society/ginger-infra:latest

# Copy setup script
COPY mount-ginger-credentials.sh /usr/local/bin/mount-ginger-credentials.sh
RUN chmod +x /usr/local/bin/mount-ginger-credentials.sh