# multi-arch-rust.Dockerfile
FROM rust:1-slim-bullseye

ARG TARGETARCH

RUN apt update && apt install -y \
    pkg-config \
    libssl-dev \
    curl \
    gcc-mingw-w64-x86-64 \
    gcc-aarch64-linux-gnu \
    perl \
    make \
    libgtk-3-dev libglib2.0-dev libcairo2-dev libpango1.0-dev \
    libatk1.0-dev libgdk-pixbuf2.0-dev \
    libxdo-dev libpq-dev \
    musl-tools musl-dev

# ── musl include symlink workaround (arch-aware) ─────────────────────────
# musl-dev doesn't ship the linux kernel headers (asm, asm-generic) that
# some crates (e.g. ring) expect. We borrow them from the matching
# glibc multiarch include dir for whichever arch we're building on.
RUN set -eux; \
    if [ "$TARGETARCH" = "amd64" ]; then \
      mkdir -p /usr/include/x86_64-linux-musl && \
      ln -sf /usr/include/x86_64-linux-gnu/asm /usr/include/x86_64-linux-musl/asm && \
      ln -sf /usr/include/generic /usr/include/x86_64-linux-musl/generic ; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      mkdir -p /usr/include/aarch64-linux-musl && \
      ln -sf /usr/include/aarch64-linux-gnu/asm /usr/include/aarch64-linux-musl/asm && \
      ln -sf /usr/include/generic /usr/include/aarch64-linux-musl/generic ; \
    else \
      echo "Unknown TARGETARCH: $TARGETARCH" && exit 1 ; \
    fi

# ── musl-gcc wrapper symlink so cc-rs finds the triple-prefixed name ────
RUN set -eux; \
    if [ "$TARGETARCH" = "amd64" ]; then \
      ln -sf /usr/bin/musl-gcc /usr/bin/x86_64-linux-musl-gcc ; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      ln -sf /usr/bin/musl-gcc /usr/bin/aarch64-linux-musl-gcc ; \
    fi

RUN rustup target add x86_64-pc-windows-gnu
RUN rustup target add aarch64-unknown-linux-gnu
RUN rustup target add aarch64-apple-darwin
RUN rustup target add x86_64-unknown-linux-gnu
RUN rustup target add x86_64-apple-darwin
RUN rustup target add aarch64-unknown-linux-musl
RUN rustup target add x86_64-unknown-linux-musl

# ── cargo linker config for cross targets ───────────────────────────────
RUN mkdir -p /root/.cargo && \
    cat >> /root/.cargo/config.toml <<'EOF'
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"

[target.x86_64-unknown-linux-musl]
linker = "musl-gcc"

[target.aarch64-unknown-linux-musl]
linker = "aarch64-linux-musl-gcc"
EOF