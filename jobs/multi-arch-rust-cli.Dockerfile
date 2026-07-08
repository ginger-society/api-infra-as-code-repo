# Dockerfile.build
FROM rust:1-slim-bullseye

RUN apt update && apt install -y \
    docker.io \
    pkg-config \
    libssl-dev \
    curl \
    gcc-mingw-w64-x86-64 \
    gcc-aarch64-linux-gnu \
    default-jdk-headless \
    perl \
    make

# ── Node.js (via NodeSource) ────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt install -y nodejs \
    && apt clean

# ── OpenAPI Generator CLI + pre-download JAR ─────────────────────────────────
RUN npm install -g @openapitools/openapi-generator-cli \
    && openapi-generator-cli version-manager set 7.12.0 \
    && openapi-generator-cli version

RUN rustup target add x86_64-pc-windows-gnu
RUN rustup target add aarch64-unknown-linux-gnu
RUN rustup target add aarch64-apple-darwin
RUN rustup target add x86_64-unknown-linux-gnu
RUN rustup target add x86_64-apple-darwin
RUN rustup target add aarch64-unknown-linux-musl
RUN rustup target add x86_64-unknown-linux-musl

# ── Ginger pipeline CLIs ─────────────────────────────────────────────────────
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ginger-society/infra-as-code-repo/main/rust-helpers/install-pipeline-clis.sh)"
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ginger-society/infra-as-code-repo/main/rust-helpers/installer.sh)" -- ginger-society/ginger-infra:latest


COPY configure_buildah.sh /usr/local/bin/configure_buildah.sh
COPY mount-docker-credentials.sh /usr/local/bin/mount-docker-credentials.sh
COPY mount-ginger-credentials.sh /usr/local/bin/mount-ginger-credentials.sh
RUN chmod +x /usr/local/bin/configure_buildah.sh /usr/local/bin/mount-docker-credentials.sh /usr/local/bin/mount-ginger-credentials.sh


# Configure cargo to use the correct linker for aarch64
RUN mkdir -p /root/.cargo && \
    echo '[target.aarch64-unknown-linux-gnu]' >> /root/.cargo/config.toml && \
    echo 'linker = "aarch64-linux-gnu-gcc"' >> /root/.cargo/config.toml