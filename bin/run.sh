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

# Check for source files in the project
check_source_files() {
    if [ -d "src" ] || [ -f "src/main.rs" ] || [ -f "src/lib.rs" ]; then
        return 0
    fi

    echo -e "\n❌ Fout: Geen bronbestanden gevonden in de huidige map"
    echo -e "   Dit script moet worden uitgevoerd in een map met een Rust project."
    echo -e "   Zorg voor een 'src/main.rs' of 'src/lib.rs' bestand of voer dit uit in een projectmap.\n"
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
    cat << EOF

Gebruik: $(basename "$0") [COMMAND] [OPTIES]

Een hulpprogramma voor het ontwikkelen van Rust projecten in een Docker container.

Commands:
    dev [VERSION]   Start een ontwikkelcontainer met Rust VERSION (standaard: latest)
    build           Bouw het project in release modus
    build --debug   Bouw het project in debug modus
    musl            Bouw een statische binary met MUSL
    test            Voer tests uit
    run             Voer de applicatie uit
    shell           Open een shell in de container
    clean           Verwijder build artifacts en caches
    help, --help    Toon deze hulp

Voorbeelden:
    # Start een ontwikkelcontainer met de nieuwste Rust versie
    $0 dev

    # Bouw het project in release modus
    $0 build

    # Bouw een statische binary met MUSL
    $0 musl

    # Start een ontwikkelcontainer met een specifieke Rust versie
    $0 dev 1.70.0

    # Bouw het project in release modus
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
    local profile="--release"
    if [ "$#" -gt 0 ] && [ "$1" = "--debug" ]; then
        profile=""
    fi
    echo -e "🔧 Building application ${profile:+(${profile#--})}..."
    run_command cargo build ${profile}
}

# Function to run tests
test() {
    echo -e "🧪 Running tests..."
    run_command cargo test -- --nocapture
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
musl_build() {
    local rust_version="${1:-latest}"  # Default to 'latest' if no version specified
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

    # Create a temporary script file
    local temp_script
    temp_script=$(mktemp)

    # Ensure the temp file is removed on exit
    trap 'rm -f "$temp_script"' EXIT

    # Write the build script to the temporary file
    cat > "$temp_script" << 'EOF_BUILD_SCRIPT'
#!/bin/sh
set -e

# Install required packages
echo "Updating package lists..."
apt-get update -qq

# Install musl-tools if not already installed
if ! command -v musl-gcc >/dev/null 2>&1; then
    echo "Installing musl-tools..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        musl-tools \
        musl-dev
fi

# Add MUSL target if not already added
if ! rustup target list | grep -q "x86_64-unknown-linux-musl (installed)"; then
    echo "Adding MUSL target..."
    rustup target add x86_64-unknown-linux-musl
fi

echo "Building application..."

# Show current directory and contents before build
echo -e "\n📂 Current directory before build:"
pwd
ls -la

# Get package name from Cargo.toml
local cargo_toml="/app/Cargo.toml"
if [ ! -f "${cargo_toml}" ]; then
    echo -e '❌ Error: Cargo.toml not found in /app' >&2
    exit 1
fi

local package_name
package_name=$(grep -m 1 '^name = ' "${cargo_toml}" | cut -d'"' -f2)
if [ -z "${package_name}" ]; then
    echo -e '❌ Error: Could not determine package name from Cargo.toml' >&2
    exit 1
fi

# Build the application
cargo build --release --target x86_64-unknown-linux-musl

# Find the built binary
local binary_path="/app/target/x86_64-unknown-linux-musl/release/${package_name}"

# Check if binary exists and is executable
if [ ! -f "$binary_path" ] || [ ! -x "$binary_path" ]; then
    echo -e "❌ Error: Binary exists but is not executable or accessible" >&2
    ls -la "$(dirname "$binary_path")" >&2
    exit 1
fi

echo -e "\n✅ Build successful!"
echo -e "📦 Binary location: $binary_path"
EOF_BUILD_SCRIPT

    # Make the script executable
    chmod +x "$temp_script"

    # Run the build in the container as root
    if ! docker run --rm -it \
        --user root \
        -v "${PROJECT_ROOT}:/app" \
        -v "${VOLUME_NAME}-cargo:/usr/local/cargo/registry" \
        -v "${VOLUME_NAME}-rustup:/usr/local/rustup" \
        -w /app \
        -e RUSTFLAGS='-C target-feature=+crt-static' \
        -e RUST_BACKTRACE=1 \
        "${IMAGE_NAME}" \
        /bin/sh -c "cat > /tmp/build.sh && chmod +x /tmp/build.sh && /tmp/build.sh" < "$temp_script"; then
        # If we get here, the build failed
        echo -e "❌ Build failed - check the output above for details" >&2
        return 1
    fi

    # If we get here, the build was successful
    echo -e "\n✅ MUSL build completed successfully!"
    echo -e "📦 The static binary is available at: ${PROJECT_ROOT}/target/x86_64-unknown-linux-musl/release/"

    # Show the binary information if it exists
    local binary_path
    binary_path="${PROJECT_ROOT}/target/x86_64-unknown-linux-musl/release/$(grep -m 1 '^name = ' "${PROJECT_ROOT}/Cargo.toml" | cut -d'"' -f2)"
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
        musl)
            musl_build "${2:-}"
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
