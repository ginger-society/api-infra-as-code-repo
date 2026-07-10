# Dockerfile.build
FROM rust:1-slim-bullseye

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
    libxdo-dev


RUN rustup target add x86_64-pc-windows-gnu
RUN rustup target add aarch64-unknown-linux-gnu
RUN rustup target add aarch64-apple-darwin
RUN rustup target add x86_64-unknown-linux-gnu
RUN rustup target add x86_64-apple-darwin
RUN rustup target add aarch64-unknown-linux-musl
RUN rustup target add x86_64-unknown-linux-musl

# Configure cargo to use the correct linker for aarch64
RUN mkdir -p /root/.cargo && \
    echo '[target.aarch64-unknown-linux-gnu]' >> /root/.cargo/config.toml && \
    echo 'linker = "aarch64-linux-gnu-gcc"' >> /root/.cargo/config.toml