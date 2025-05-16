#!/bin/bash
set -e

# Determine the project root path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Read package name from Cargo.toml
PACKAGE_NAME=$(grep -m 1 '^name =' "$PROJECT_ROOT/Cargo.toml" | sed -E 's/^name *= *"([^"]+)".*/\1/')
if [ -z "$PACKAGE_NAME" ]; then
    echo "❌ Could not determine package name from Cargo.toml"
    exit 1
fi

# Configuration
IMAGE_NAME="$PACKAGE_NAME"
CONTAINER_NAME="${IMAGE_NAME}-container"

# Function to build the builder image
build_builder() {
    local rust_version="${1:-latest}"  # Default to 'latest' if no version specified
    echo "🔨 Building builder image with Rust ${rust_version}..."
    (cd "$PROJECT_ROOT" && docker build \
        --target builder \
        --build-arg RUST_VERSION="${rust_version}" \
        -t "${IMAGE_NAME}-builder" \
        -f "docker/Dockerfile" .)
}

# Function to build the runtime image
build_runtime() {
    echo "🚀 Building runtime image..."
    (cd "$PROJECT_ROOT" && docker build -t "${IMAGE_NAME}" -f "docker/Dockerfile" .)
}

# Function to start the development container
dev() {
    local rust_version="${1:-latest}"  # Default to 'latest' if no version specified
    echo "👨‍💻 Starting development container with Rust ${rust_version}..."
    build_builder "$rust_version"
    (cd "$PROJECT_ROOT" && docker run -it --rm \
        --name "${CONTAINER_NAME}" \
        -v "$PROJECT_ROOT:/app" \
        -w /app \
        -e RUST_BACKTRACE=1 \
        -e RUST_LOG=info \
        "${IMAGE_NAME}-builder" \
        cargo watch -x run
    )
}

# Function to build the application
build() {
    echo "🔧 Building application..."
    (cd "$PROJECT_ROOT" && docker build -t "${IMAGE_NAME}" -f "$SCRIPT_DIR/Dockerfile" .)
}

# Function to run the application
run() {
    echo "🚀 Running application..."
    (cd "$PROJECT_ROOT" && docker run \
        --rm \
        -it \
        --name "${CONTAINER_NAME}" \
        -v "$PROJECT_ROOT/config:/app/config" \
        -e RUST_BACKTRACE=1 \
        -e RUST_LOG=info \
        "${IMAGE_NAME}" \
        "$@"
    )
}

# Function to clean up containers and images
clean() {
    echo "🧹 Cleaning up..."
    docker rmi -f "${IMAGE_NAME}" "${IMAGE_NAME}-builder" 2>/dev/null || true
    docker builder prune -f
}

# Function to create a MUSL build
musl_build() {
    local rust_version="${1:-latest}"  # Default to 'latest' if no version specified
    echo "🔨 Building MUSL static binary with Rust ${rust_version}..."

    # Create a volume for Rust cache if it doesn't exist
    if ! docker volume inspect rust_cache >/dev/null 2>&1; then
        echo "Creating rust_cache volume..."
        docker volume create --name rust_cache
    fi

    # Create a volume for apt cache
    if ! docker volume inspect apt_cache >/dev/null 2>&1; then
        echo "Creating apt_cache volume..."
        docker volume create --name apt_cache
    fi

    # Create a volume for cargo registry
    if ! docker volume inspect cargo_registry >/dev/null 2>&1; then
        echo "Creating cargo_registry volume..."
        docker volume create --name cargo_registry
    fi

    docker run --rm -it \
        -v "$PROJECT_ROOT:/app" \
        -v rust_cache:/root/.cache \
        -v cargo_registry:/usr/local/cargo/registry \
        -v apt_cache:/var/cache/apt \
        -v apt_cache:/var/lib/apt/lists \
        -w /app \
        -e RUSTFLAGS='-C target-feature=+crt-static' \
        -e CARGO_HOME=/usr/local/cargo \
        "rust:${rust_version}" \
        bash -c "
            # Install musl-tools if not already installed
            if ! command -v musl-gcc >/dev/null 2>&1; then
                echo 'Installing musl-tools...' && \
                apt-get update -qq && \
                apt-get install -y --no-install-recommends musl-tools
            fi && \
            
            # Add MUSL target if not already added
            if ! rustup target list | grep -q 'x86_64-unknown-linux-musl (installed)'; then
                echo 'Adding MUSL target...' && \
                rustup target add x86_64-unknown-linux-musl
            fi && \
            
            echo 'Building application...' && \
            cargo build --release --target x86_64-unknown-linux-musl && \
            echo -e '\\n✅ Build successful! Binary location:' && \
            ls -lh /app/target/x86_64-unknown-linux-musl/release/${PACKAGE_NAME}
        "
}

# Show help
show_help() {
    cat << EOF
Usage: $0 [command] [options]

Commands:
  dev [rust_version]  Start development environment with optional Rust version
  build               Build the application
  run                 Run the application
  clean               Clean up Docker resources
  musl [rust_version] Create a MUSL build with optional Rust version

Examples:
  $0 dev                # Use latest Rust version
  $0 dev 1.77.2         # Use Rust 1.77.2
  $0 musl 1.77.2        # Create MUSL build with Rust 1.77.2

Options:
  -h, --help  Show this help message
EOF
}

# Main script
case "$1" in
    dev)
        shift
        dev "$1"
        ;;
    build)
        build
        ;;
    run)
        shift
        run "$@"
        ;;
    clean)
        clean
        ;;
    musl)
        shift
        musl_build "$1"
        ;;
    -h|--help)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
