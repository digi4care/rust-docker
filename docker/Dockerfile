# Use the official Rust image as the base image
ARG RUST_VERSION=latest
FROM rust:${RUST_VERSION}

# Install common development tools and utilities
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    build-essential \
    pkg-config \
    libssl-dev \
    musl-tools \
    musl-dev \
    musl \
    musl-utils \
    musl-libc \
    musl-libc-dev \
    musl-tools \
    gcc-musl \
    g++-musl \
    file \
    binutils \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# Install common Rust targets
RUN rustup target add wasm32-unknown-unknown \
    && rustup target add x86_64-unknown-linux-musl \
    && rustup target add x86_64-unknown-linux-gnu \
    && rustup component add rustfmt \
    && rustup component add clippy \
    && rustup component add rust-src \
    && rustup component add rust-analysis

# Install cargo-edit for Cargo.toml editing
RUN cargo install cargo-edit \
    && cargo install cargo-watch \
    && cargo install cargo-audit \
    && cargo install cargo-outdated \
    && cargo install cargo-udeps --locked \
    && cargo install cargo-tarpaulin

# Install wasm-pack for WebAssembly
RUN curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

# Create a non-root user
RUN useradd -m -s /bin/bash rustdev

# Set the working directory
WORKDIR /app

# Switch to non-root user
USER rustdev

# Set environment variables
ENV RUST_BACKTRACE=1
ENV RUST_LOG=info

# Default command
CMD ["/bin/bash"]