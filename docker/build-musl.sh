#!/bin/bash
set -e

# Install musl-tools if not already installed
if ! command -v musl-gcc >/dev/null 2>&1; then
    echo "Installing musl-tools..."
    apt-get update -qq
    apt-get install -y --no-install-recommends musl-tools
fi

# Add MUSL target if not already added
if ! rustup target list | grep -q "x86_64-unknown-linux-musl (installed)"; then
    echo "Adding MUSL target..."
    rustup target add x86_64-unknown-linux-musl
fi

echo "Building application..."
cargo build --release --target x86_64-unknown-linux-musl
echo -e "\n✅ Build successful! Binary location:"
ls -lh "/app/target/x86_64-unknown-linux-musl/release/${PACKAGE_NAME}"
