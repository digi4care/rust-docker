# First stage: Builder with MUSL support
FROM rust:latest AS builder

# Install MUSL tools and target
RUN apt-get update && \
    apt-get install -y musl-tools musl-dev && \
    rustup target add x86_64-unknown-linux-musl

# Create a new empty shell project
RUN USER=root cargo new --bin app
WORKDIR /app

# Copy manifest files
COPY ["Cargo.toml", "Cargo.lock", "./"]

# Build only the dependencies with MUSL target (cached as long as Cargo.toml doesn't change)
RUN mkdir -p ./src && \
    echo 'fn main() { println!("Dummy main") }' > ./src/main.rs && \
    cargo build --release --target x86_64-unknown-linux-musl && \
    rm -f target/x86_64-unknown-linux-musl/release/deps/proxmox_vm_manager*

# Copy source files
COPY src/ src/

# Build the application with MUSL target (uses cached dependencies)
RUN touch src/main.rs && \
    cargo build --release --target x86_64-unknown-linux-musl

# Second stage: Runtime image
FROM debian:bookworm-slim

# Install only ca-certificates (no libssl needed for MUSL build)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy the MUSL binary from the builder stage
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/proxmox-vm-manager /usr/local/bin/

# Set the working directory
WORKDIR /app

# Run the application
CMD ["/bin/bash"]