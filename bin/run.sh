#!/bin/bash
set -euo pipefail

# Determine the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Script configuration

# Global variables
declare PROJECT_ROOT

declare PACKAGE_NAME
declare IMAGE_NAME
declare CONTAINER_NAME
declare VOLUME_NAME

# Find the project root (current directory or parent with Cargo.toml)
find_project_root() {
    local dir="$PWD"  # Always start from current directory
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/Cargo.toml" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo "$PWD"  # Fallback to current directory if no Cargo.toml found
}

# Initialize project variables
init_project() {
    PROJECT_ROOT="$(find_project_root)"
    cd "$PROJECT_ROOT" || exit 1

    # Try to get package name from Cargo.toml if it exists
    PACKAGE_NAME="rust-dev-utility"
    if [ -f "Cargo.toml" ]; then
        PACKAGE_NAME=$(grep -m 1 '^name =' "Cargo.toml" | sed -E 's/^name *= *"([^"]+)".*/\1/' || echo "rust-dev-utility")
    fi

    # Configuration
    IMAGE_NAME="rust-dev-utility"
    CONTAINER_NAME="${PACKAGE_NAME}-container"
    VOLUME_NAME="${PWD##*/}-rust-cache"
}

# Initialize project variables
init_project

# Function to ensure volumes exist
ensure_volumes() {
    # Create volume for Rust cache if it doesn't exist
    if ! docker volume inspect "${VOLUME_NAME}-cargo" >/dev/null 2>&1; then
        echo -e "${BLUE}🔧 Creating volume ${VOLUME_NAME}-cargo...${NC}"
        if ! docker volume create "${VOLUME_NAME}-cargo" >/dev/null 2>&1; then
            echo -e "${RED}❌ Failed to create volume ${VOLUME_NAME}-cargo${NC}" >&2
            return 1
        fi
    fi

    # Create volume for Rust toolchain
    if ! docker volume inspect "${VOLUME_NAME}-rustup" >/dev/null 2>&1; then
        echo -e "${BLUE}🔧 Creating volume ${VOLUME_NAME}-rustup...${NC}"
        if ! docker volume create "${VOLUME_NAME}-rustup" >/dev/null 2>&1; then
            echo -e "${RED}❌ Failed to create volume ${VOLUME_NAME}-rustup${NC}" >&2
            return 1
        fi
    fi

    return 0
}

# Function to build the builder image
build_builder() {
    local rust_version="${1:-latest}"  # Default to 'latest' if no version specified
    echo -e "${BLUE}🔨 Building builder image with Rust ${rust_version}...${NC}"

    ensure_volumes

    docker build \
        --build-arg RUST_VERSION="${rust_version}" \
        -t "${IMAGE_NAME}" \
        -f "${SCRIPT_DIR}/../docker/Dockerfile" \
        "${SCRIPT_DIR}/.."
}

# Function to build the runtime image
build_runtime() {
    echo "🚀 Building runtime image..."
    (cd "$PROJECT_ROOT" && docker build -t "${IMAGE_NAME}" -f "docker/Dockerfile" .)
}

# Function to start the development container
dev() {
    local rust_version="${1:-latest}"  # Default to 'latest' if no version specified
    echo -e "${BLUE}👨‍💻 Starting development container with Rust ${rust_version}...${NC}"

    ensure_volumes

    docker run -it --rm \
        --name "${CONTAINER_NAME}" \
        -v "${PWD}:/app" \
        -v "${VOLUME_NAME}-cargo:/usr/local/cargo/registry" \
        -v "${VOLUME_NAME}-rustup:/usr/local/rustup" \
        -w /app \
        -e RUST_BACKTRACE=1 \
        -e RUST_LOG=info \
        "${IMAGE_NAME}" \
        cargo watch -x "build --all-features" -x run
}

# Function to run a command in the container
run_command() {
    if ! ensure_volumes; then
        return 1
    fi

    local cmd=("$@")
    echo -e "${BLUE}🚀 Running command: ${cmd[*]}${NC}"

    if ! docker run -it --rm \
        -v "${PWD}:/app" \
        -v "${VOLUME_NAME}-cargo:/usr/local/cargo/registry" \
        -v "${VOLUME_NAME}-rustup:/usr/local/rustup" \
        -w /app \
        -e RUST_BACKTRACE=1 \
        -e RUST_LOG=info \
        "${IMAGE_NAME}" \
        "${cmd[@]}"; then
        echo -e "${RED}❌ Command failed${NC}" >&2
        return 1
    fi
}

# Function to build the application
build() {
    local profile="--release"
    if [ "$#" -gt 0 ] && [ "$1" = "--debug" ]; then
        profile=""
    fi
    echo -e "${BLUE}🔧 Building application ${profile:+(${profile#--})}...${NC}"
    run_command cargo build ${profile}
}

# Function to run tests
test() {
    echo -e "${BLUE}🧪 Running tests...${NC}"
    run_command cargo test -- --nocapture
}

# Function to check code
check() {
    echo -e "${BLUE}🔍 Checking code...${NC}"
    run_command cargo check
}

# Function to run clippy
clippy() {
    echo "Running clippy..."
    run_command cargo clippy -- -D warnings
}

# Function to format code
fmt() {
    echo "Formatting code..."
    run_command cargo fmt -- --check
}

# Function to clean
clean() {
    echo "Cleaning project and Docker resources..."
    run_command cargo clean
    
    # Clean up Docker resources
    docker rmi -f "${IMAGE_NAME}" "${IMAGE_NAME}-builder" 2>/dev/null || true
    docker builder prune -f
}

# Function to enter the container shell
shell() {
    echo "Entering container shell..."
    echo "Type 'exit' to leave the container shell"
    run_command /bin/bash
}

# Function to run the application
run() {
    echo "Running application..."
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

# Function to create a MUSL build

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
Usage: $0 <command> [options]

Commands:
  dev [rust-version]    Start development server with hot-reload
  build [--debug|--release]  Build the application (default: --release)
  run [args...]        Run the application with optional arguments
  test                 Run tests
  check                Check the code
  clippy               Run clippy
  fmt                  Format the code
  clean                Clean the project
  shell                Enter a shell in the container
  help                 Show this help message

Examples:
  $0 dev                 # Start dev server with default Rust version
  $0 build --debug      # Build in debug mode
  $0 test              # Run tests
  $0 shell             # Enter container shell
  $0 help              # Show this help message

Environment variables:
  RUST_BACKTRACE=1  Enable backtraces on panic
  RUST_LOG=info     Set log level (error, warn, info, debug, trace)

Tip: Add an alias to your shell config:
  echo 'alias rustdev="path/to/run.sh"' >> ~/.zshrc  # or ~/.bashrc
  source ~/.zshrc  # or ~/.bashrc

  Then use it in any Rust project:
  $ rustdev build
  $ rustdev test
  $ rustdev shell
EOF
}

# Main script
main() {
    # Initialize project variables
    init_project

    case "${1:-help}" in
        dev)
            shift
            dev "$@"
            ;;
        build)
            shift
            build "$@"
            ;;
        run)
            shift
            run_command cargo run -- "$@"
            ;;
        test)
            shift
            test "$@"
            ;;
        check)
            shift
            check "$@"
            ;;
        clippy)
            shift
            clippy "$@"
            ;;
        fmt)
            shift
            fmt "$@"
            ;;
        clean)
            shift
            clean "$@"
            ;;
        shell)
            shift
            shell "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            # If no command matches, run it directly in the container
            run_command "$@"
            ;;
    esac
}

# Only run main if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
