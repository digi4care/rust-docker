#!/bin/bash
set -e

# Determine the project root path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
IMAGE_NAME="proxmox-vm-manager"
CONTAINER_NAME="${IMAGE_NAME}-container"

# Function to build the builder image
build_builder() {
    echo "🔨 Building builder image..."
    (cd "$PROJECT_ROOT" && docker build --target builder -t "${IMAGE_NAME}-builder" -f "$SCRIPT_DIR/Dockerfile" .)
}

# Function to build the runtime image
build_runtime() {
    echo "🚀 Building runtime image..."
    (cd "$PROJECT_ROOT" && docker build -t "${IMAGE_NAME}" -f "$SCRIPT_DIR/Dockerfile" .)
}

# Function to start the development container
dev() {
    echo "👨‍💻 Starting development container..."
    docker run -it --rm \
        --name "${CONTAINER_NAME}" \
        -v "$PROJECT_ROOT:/app" \
        -w /app \
        -e RUST_BACKTRACE=1 \
        -e RUST_LOG=debug \
        rust:1.75-bookworm \
        bash -c "cargo install cargo-watch && /bin/bash"
}

# Function to build the application
build() {
    echo "🔧 Building application..."
    (cd "$PROJECT_ROOT" && docker build -t "${IMAGE_NAME}" -f "$SCRIPT_DIR/Dockerfile" .)
}

# Function to run the application
run() {
    echo "🚀 Starting application..."
    docker run -it --rm \
        --name "${CONTAINER_NAME}" \
        -v "$PROJECT_ROOT/config:/app/config" \
        -e RUST_BACKTRACE=1 \
        -e RUST_LOG=info \
        "${IMAGE_NAME}" \
        "$@"
}

# Function to clean up containers and images
clean() {
    echo "🧹 Cleaning up..."
    docker rmi -f "${IMAGE_NAME}" "${IMAGE_NAME}-builder" 2>/dev/null || true
    docker builder prune -f
}

# Function to create a MUSL build
musl_build() {
    echo "🔨 Building MUSL static binary with caching..."
    
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
        rust:latest \
        bash -c "
            # Installeer alleen als het nog niet geïnstalleerd is
            if ! command -v musl-gcc >/dev/null 2>&1; then
                echo 'Installing musl-tools...' && \
                apt-get update -qq && \
                apt-get install -y --no-install-recommends musl-tools
            fi && \
            
            # Voeg target toe als het nog niet bestaat
            if ! rustup target list | grep -q 'x86_64-unknown-linux-musl (installed)'; then
                echo 'Adding MUSL target...' && \
                rustup target add x86_64-unknown-linux-musl
            fi && \
            
            # Bouw de applicatie
            echo 'Building application...' && \
            cargo build --release --target x86_64-unknown-linux-musl && \
            echo -e '\n✅ Build successful! Binary location:' && \
            ls -lh /app/target/x86_64-unknown-linux-musl/release/proxmox-vm-manager
        "
}

# Show help
show_help() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  dev       Start development container"
    echo "  build     Build the application"
    echo "  musl      Build a static binary with MUSL"
    echo "  run       Run the application (pass additional args to the app)"
    echo "  clean     Remove all Docker artifacts"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dev          # Start development environment"
    echo "  $0 build        # Build the application"
    echo "  $0 run          # Run the application"
    echo "  $0 run --help   # Show application help"
}

# Main script
case "$1" in
    dev)
        dev
        ;;
    build)
        build
        ;;
    run)
        shift  # Remove 'run' from arguments
        run "$@"
        ;;
    musl)
        musl_build
        ;;
    clean)
        clean
        ;;
    help|--help|-h|*)
        show_help
        ;;
esac
