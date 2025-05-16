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

# Version information
declare VERSION="1.0.0"
declare AUTHOR="Chris Engelhard <chris@chrisengelhard.nl>"
declare DESCRIPTION="Rust Development Utility - A Docker-based development environment for Rust projects"

# Display header
show_header() {
    echo "Rust Development Utility v${VERSION}"
    echo "├── Author: ${AUTHOR}"
    echo "└── ${DESCRIPTION}"
    echo ""
}

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

# Check for source files in the project
check_source_files() {
    if [ -d "src" ] || [ -f "src/main.rs" ] || [ -f "src/lib.rs" ]; then
        return 0
    fi

    echo -e "\n❌ Error: No source files found in the current directory"
    echo -e "   This script must be run in a directory with a Rust project."
    echo -e "   Please ensure there is a 'src/main.rs' or 'src/lib.rs' file or run this in a project directory.\n"
    return 1
}

# Initialize project variables
init_project() {
    local check_source="${1:-}"  # Make parameter optional with default empty value
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

    # Check for source files in the project root if requested
    if [ "$check_source" = "check" ] && ! check_source_files; then
        exit 1
    fi
}

# Show help if no arguments are provided
show_help() {
    show_header
    cat << EOF

Usage: $(basename "$0") [COMMAND] [OPTIONS]

A utility for developing Rust projects in a Docker container.

Commands:
    dev [VERSION]   Start a development container with Rust VERSION (default: latest)
    build [VERSION] Build the project in release mode with optional Rust VERSION
    build --debug   Build the project in debug mode
    musl [VERSION]  Build a static binary with MUSL using optional Rust VERSION
    test [VERSION]  Run tests with optional Rust VERSION
    run             Run the application
    shell [VERSION] Open a shell in the container with optional Rust VERSION
    clean           Remove build artifacts and caches
    help, --help    Show this help message

Examples:
    # Start a development container with the latest Rust version
    $0 dev

    # Build the project in release mode
    $0 build

    # Build a static binary with MUSL
    $0 musl

    # Start a development container with a specific Rust version
    $0 dev 1.70.0

    # Build the project in release mode
    $0 build

EOF
}

# Initialize project with source check for non-help commands
if [ "$#" -eq 0 ]; then
    show_help
    exit 0
elif [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ]; then
    show_help
    exit 0
else
    # Only check for source files if it's not a help command
    init_project check
fi

# Function to ensure volumes exist and have correct permissions
ensure_volumes() {
    # Create volume for Rust cache if it doesn't exist
    if ! docker volume inspect "${VOLUME_NAME}-cargo" >/dev/null 2>&1; then
        echo -e "🔧 Creating volume ${VOLUME_NAME}-cargo..."
        if ! docker volume create "${VOLUME_NAME}-cargo" >/dev/null 2>&1; then
            echo -e "❌ Failed to create volume ${VOLUME_NAME}-cargo" >&2
            return 1
        fi

        # Set correct permissions for new volume
        echo -e "🔧 Setting permissions for ${VOLUME_NAME}-cargo..."
        docker run --rm -v "${VOLUME_NAME}-cargo:/cargo" busybox \
            sh -c "mkdir -p /cargo/registry /cargo/git && chown -R 1000:1000 /cargo"
    fi

    # Create volume for Rust toolchain
    if ! docker volume inspect "${VOLUME_NAME}-rustup" >/dev/null 2>&1; then
        echo -e "🔧 Creating volume ${VOLUME_NAME}-rustup..."
        if ! docker volume create "${VOLUME_NAME}-rustup" >/dev/null 2>&1; then
            echo -e "❌ Failed to create volume ${VOLUME_NAME}-rustup" >&2
            return 1
        fi

        # Set correct permissions for new volume
        echo -e "🔧 Setting permissions for ${VOLUME_NAME}-rustup..."
        docker run --rm -v "${VOLUME_NAME}-rustup:/rustup" busybox \
            sh -c "chown -R 1000:1000 /rustup"
    fi

    return 0
}

# Function to build the builder image
build_builder() {
    local rust_version="${1:-latest}"  # Default to 'latest' if no version specified
    echo -e "🔨 Building builder image with Rust ${rust_version}..."

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
    echo -e "👨‍💻 Starting development container with Rust ${rust_version}..."

    # Check for source files first
    if ! check_source_files; then
        return 1
    fi

    # Ensure volumes exist
    if ! ensure_volumes; then
        return 1
    fi

    # Use the specified Rust version or default to 'latest'
    local rust_image="rust:${rust_version}"

    echo -e "🐳 Using Docker image: ${rust_image}"

    docker run -it --rm \
        --name "${CONTAINER_NAME}" \
        -v "${PWD}:/app" \
        -v "${VOLUME_NAME}-cargo:/usr/local/cargo/registry" \
        -v "${VOLUME_NAME}-rustup:/usr/local/rustup" \
        -w /app \
        -e RUST_BACKTRACE=1 \
        -e RUST_LOG=info \
        "${rust_image}" \
        sh -c "
            rustc --version &&
            cargo --version &&
            if ! command -v cargo-watch >/dev/null 2>&1; then
                echo 'Installing cargo-watch...' &&
                cargo install cargo-watch
            fi &&
            cargo watch -x 'build --all-features' -x run
        "
}



# Function to run a command in the container
run_command() {
    if ! ensure_volumes; then
        return 1
    fi

    if ! check_source_files; then
        return 1
    fi

    local cmd=("$@")
    echo -e "🚀 Running command: ${cmd[*]}"

    # First try running as root to ensure we have permissions
    if ! docker run -it --rm \
        --user root \
        -v "${PWD}:/app" \
        -v "${VOLUME_NAME}-cargo:/usr/local/cargo/registry" \
        -v "${VOLUME_NAME}-rustup:/usr/local/rustup" \
        -w /app \
        -e RUST_BACKTRACE=1 \
        -e RUST_LOG=info \
        "${IMAGE_NAME}" \
        sh -c "chown -R 1000:1000 /usr/local/cargo /usr/local/rustup && ${cmd[*]}"; then

        echo -e "❌ Command failed" >&2
        return 1
    fi
}

# Function to build the application
build() {
    local rust_version="latest"
    local build_args=("--release")
    local build_type="release"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                build_args=()
                build_type="debug"
                shift
                ;;
            --release)
                build_args=("--release")
                build_type="release"
                shift
                ;;
            *)
                # Assume it's a version specifier
                rust_version="$1"
                shift
                ;;
        esac
    done

    echo "🔧 Building application (${build_type}) with Rust ${rust_version}..."

    # Ensure volumes exist
    if ! ensure_volumes; then
        return 1
    fi

    # Use the specified Rust version or default to 'latest'
    local rust_image="rust:${rust_version}"

    # Skip cleanup to avoid device busy errors
    echo "ℹ️  Skipping cleanup to avoid device busy errors..."

    # Run the build in the container with verbose output
    echo "🏗️  Building with command: cargo build ${build_args[*]}"
    echo "📦 Using image: ${rust_image}"
    if docker run --rm \
        -v "${PROJECT_ROOT}:/app" \
        -v "${VOLUME_NAME}-cargo:/usr/local/cargo/registry" \
        -v "${VOLUME_NAME}-target:/app/target" \
        -w /app \
        "${rust_image}" \
        bash -c "set -x && cargo build ${build_args[*]} && ls -la target/${build_type}"; then

        echo -e "\n✅ Build completed successfully with Rust ${rust_version}!"

        # Verify the binary was created
        local binary_name
        binary_name=$(grep -m 1 '^name = ' "${PROJECT_ROOT}/Cargo.toml" | cut -d'"' -f2)

        if ! docker run --rm \
            -v "${VOLUME_NAME}-target:/app/target" \
            busybox \
            ls -la "/app/target/${build_type}/${binary_name}" 2>/dev/null; then
            echo "❌ Error: Binary not found at /app/target/${build_type}/${binary_name}" >&2
            return 1
        fi

        return 0
    else
        echo -e "\n❌ Build failed with Rust ${rust_version}" >&2

        # Show build logs
        echo "\n📝 Build logs:"
        docker run --rm \
            -v "${VOLUME_NAME}-target:/app/target" \
            busybox \
            find /app/target -type f -name "*.log" -exec echo "=== {} ===" \; -exec cat {} \;

        return 1
    fi
}

# Function to run tests
test() {
    # First argument is the Rust version, rest are passed to cargo test
    local rust_version="${1:-latest}"  # Default to 'latest' if no version specified
    shift  # Remove the version from arguments

    echo -e "🧪 Running tests with Rust ${rust_version}..."

    # Ensure volumes exist
    if ! ensure_volumes; then
        return 1
    fi

    # Run tests in the container
    if docker run --rm \
        -v "${PROJECT_ROOT}:/app" \
        -v "${VOLUME_NAME}-cargo:/usr/local/cargo/registry" \
        -v "${VOLUME_NAME}-rustup:/usr/local/rustup" \
        -w /app \
        -e RUST_BACKTRACE=1 \
        "rust:${rust_version}" \
        cargo test "$@"; then
        echo -e "\n✅ Tests completed successfully with Rust ${rust_version}!"
    else
        echo -e "\n❌ Tests failed with Rust ${rust_version}" >&2
        return 1
    fi
}

# Function to check code
check() {
    echo -e "🔍 Checking code..."
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
    echo "🧹 Cleaning project and Docker resources..."

    # Run cargo clean in the container
    if docker run --rm \
        -v "${PROJECT_ROOT}:/app" \
        -v "${VOLUME_NAME}-cargo:/usr/local/cargo/registry" \
        -v "${VOLUME_NAME}-rustup:/usr/local/rustup" \
        -w /app \
        rust:latest \
        cargo clean; then
        echo -e "\n✅ Project cleaned successfully!"
    else
        echo -e "\n❌ Failed to clean project" >&2
        return 1
    fi

    # Clean up Docker builder cache
    echo -e "\n🧹 Cleaning Docker builder cache..."

        echo -e "\n✅ Cleanup complete!"
    }

    # Function to open a shell in the container
    shell() {
        # First argument is the Rust version
        local rust_version="${1:-latest}"  # Default to 'latest' if no version specified
        shift  # Remove the version from arguments

        echo "Entering container shell with Rust ${rust_version}..."
        echo "Type 'exit' to leave the container shell"

        # Ensure volumes exist
        if ! ensure_volumes; then
            return 1
        fi

        # Run an interactive shell in the container
        docker run -it --rm \
            -v "${PROJECT_ROOT}:/app" \
            -v "${VOLUME_NAME}-cargo:/usr/local/cargo/registry" \
            -v "${VOLUME_NAME}-rustup:/usr/local/rustup" \
            -w /app \
            -e RUST_BACKTRACE=1 \
            "rust:${rust_version}" \
            /bin/bash
    }

    # Function to run the application
    run() {
        echo "🚀 Running application..."

        # Ensure volumes exist
        if ! ensure_volumes; then
            return 1
        fi

        # Binary name from the build output
        local binary_name="proxmox-vm-manager"
        local release_binary="/app/target/release/${binary_name}"
        local debug_binary="/app/target/debug/${binary_name}"
        local binary_path=""

        # Check if release binary exists
        if docker run --rm \
            -v "${VOLUME_NAME}-target:/app/target" \
            busybox \
            ls "${release_binary}" >/dev/null 2>&1; then
            binary_path="${release_binary}"
            echo "✅ Found release build at: ${binary_path}"
        # Otherwise check for debug build
        elif docker run --rm \
            -v "${VOLUME_NAME}-target:/app/target" \
            busybox \
            ls "${debug_binary}" >/dev/null 2>&1; then
            binary_path="${debug_binary}"
            echo "ℹ️  Using debug build at: ${binary_path}"
        else
            echo "❌ No binary found. Building in debug mode first..."
            if ! build --debug; then
                echo "❌ Failed to build the application" >&2
                return 1
            fi
            binary_path="${debug_binary}"
        fi

        # Show target directory contents for debugging
        echo "\n📂 Target directory contents:"
        docker run --rm \
            -v "${VOLUME_NAME}-target:/app/target" \
            busybox \
            find /app/target -type f -name "${binary_name}*" 2>/dev/null || echo "No matching files found"

        # Run the binary
        echo "\n🏃 Running: ${binary_path} $*"
        docker run --rm \
            -it \
            -v "${PROJECT_ROOT}:/app" \
            -v "${VOLUME_NAME}-cargo:/usr/local/cargo/registry" \
            -v "${VOLUME_NAME}-target:/app/target" \
            -w /app \
            "rust:latest" \
            "${binary_path}" "$@"
    }

    # Function to create a MUSL build
    musl_build() {
        # First argument is the Rust version, rest are passed to cargo
        local rust_version="${1:-latest}"  # Default to 'latest' if no version specified
        shift  # Remove the version from arguments

        echo "🔨 Building MUSL static binary with Rust ${rust_version}..."
    # First argument is the Rust version, rest are passed to cargo
    local rust_version="${1:-latest}"  # Default to 'latest' if no version specified
    shift  # Remove the version from arguments

    echo "🔨 Building MUSL static binary with Rust ${rust_version}..."

    # Check for source files first
    if ! check_source_files; then
        return 1
    fi

    # Ensure volumes exist
    if ! ensure_volumes; then
        return 1
    fi

    # Create target directory with correct permissions
    mkdir -p "${PROJECT_ROOT}/target"
    chmod 777 "${PROJECT_ROOT}/target"

    # Check if build-musl.sh exists
    local build_script_path="${SCRIPT_DIR}/../docker/build-musl.sh"
    if [ ! -f "$build_script_path" ]; then
        echo "❌ Error: build-musl.sh not found at $build_script_path" >&2
        return 1
    fi

    # Make sure the script is executable
    chmod +x "$build_script_path"

    # Create docker directory if it doesn't exist
    mkdir -p "${PROJECT_ROOT}/docker"

    # Copy the build script to the project directory
    cp "$build_script_path" "${PROJECT_ROOT}/docker/"

    # Run the MUSL build in the container with the specified Rust version
    if docker run --rm \
        -v "${PROJECT_ROOT}:/app" \
        -v "${VOLUME_NAME}-cargo:/usr/local/cargo/registry" \
        -v "${VOLUME_NAME}-rustup:/usr/local/rustup" \
        -w /app \
        -e RUST_BACKTRACE=1 \
        "rust:${rust_version}" \
        /bin/sh -c "chmod +x /app/docker/build-musl.sh && /app/docker/build-musl.sh"; then

        # If we get here, the build was successful
        local binary_name
        binary_name=$(grep -m 1 '^name = ' "${PROJECT_ROOT}/Cargo.toml" | cut -d'"' -f2)
        local binary_path="${PROJECT_ROOT}/target/x86_64-unknown-linux-musl/release/${binary_name}"

        echo -e "\n✅ MUSL build completed successfully!"
        echo -e "📦 The static binary is available at: ${binary_path}"

        if [ -f "$binary_path" ]; then
            echo -e "\n📄 Binary information:"
            file "$binary_path"
            echo -e "📏 Size: $(du -h "$binary_path" | awk '{print $1}')"

            # Check if the binary is static
            if ldd "$binary_path" 2>/dev/null; then
                echo -e "\n⚠️  Warning: Binary has dynamic dependencies (not fully static)"
            else
                echo -e "\n✅ No dynamic dependencies found (fully static binary)"
            fi
        fi
    else
        echo -e "\n❌ Build failed - check the output above for details" >&2
        return 1
    fi
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
            # Handle version parameter if provided
            if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
                version="$1"
                shift
                build "$version" "$@"
            else
                build latest "$@"
            fi
            ;;
        musl)
            # Pass all remaining arguments to musl_build
            musl_build "$@"
            ;;
        test)
            shift
            # Handle version parameter if provided
            if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
                version="$1"
                shift
                test "$version" "$@"
            else
                test latest "$@"
            fi
            ;;
        run)
            shift
            run "$@"
            ;;
        shell)
            shift
            # Handle version parameter if provided
            if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
                version="$1"
                shift
                shell "$version" "$@"
            else
                shell latest "$@"
            fi
            ;;
        clean)
            shift
            clean
            ;;
        help|--help|'-h'|'')
            show_help
            ;;
        *)
            echo "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Only run main if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
