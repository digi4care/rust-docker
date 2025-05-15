# Rust Development Environment Guide

This document provides comprehensive documentation for the Rust Docker development environment.

## Table of Contents

- [Development Container](#development-container)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Building and Running](#building-and-running)
- [Testing](#testing)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [Customization](#customization)

## Development Container

The development container includes everything needed for Rust development:

- Latest stable Rust toolchain and Cargo
- Common development tools (git, vim, curl, etc.)
- Rust-analyzer for IDE support
- Cargo watch for automatic rebuilding
- Debugging tools

## Getting Started

### Prerequisites

- Docker installed on your system
- Basic knowledge of Docker and Rust

### Starting the Development Environment

```bash
# Start the development container
./docker/run.sh dev
```

This will give you an interactive shell inside the container with:
- Your source code mounted at `/workspace`
- All Rust tools available in PATH
- Proper file permissions for your user

## Development Workflow

### Using VSCode with Remote-Containers

1. Install the "Remote - Containers" extension in VSCode
2. Open the command palette (Ctrl+Shift+P) and select "Remote-Containers: Reopen in Container"
3. VSCode will build the container and attach to it
4. Install the "rust-analyzer" extension in the container when prompted

### Using Cargo Watch

For automatic rebuilding:

```bash
# Watch for changes and run tests
cargo watch -x test

# Watch for changes and run the application
cargo watch -x run
```

## Building and Running

### Development Build

```bash
# Build in debug mode (faster compilation)
./docker/run.sh build

# The binary will be available at:
# target/debug/your-app-name
```

### Release Build

```bash
# Build with optimizations
./docker/run.sh build --release

# The binary will be available at:
# target/release/your-app-name
```

### Static MUSL Build

To create a fully static binary with MUSL:

```bash
# Build a static MUSL binary
./docker/run.sh musl

# The binary will be available at:
# target/x86_64-unknown-linux-musl/release/your-app-name
```

## Testing

### Running Tests

```bash
# Run all tests
./docker/run.sh test

# Run a specific test
./docker/run.sh test test_name

# Run tests with detailed output
cargo test -- --nocapture
```

### Code Quality

```bash
# Format code
cargo fmt

# Check code style
cargo clippy

# Check for unused dependencies
cargo udeps
```

## Advanced Usage

### Docker Compose

You can use Docker Compose to manage the development environment:

```bash
# Start the development environment
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the environment
docker-compose down
```

### Environment Variables

You can customize the environment using these variables:

- `RUST_LOG`: Set the logging level (e.g., `debug`, `info`, `warn`, `error`)
- `RUST_BACKTRACE`: Enable backtraces for better error reporting

## Troubleshooting

### Common Issues

1. **Permission Issues**
   ```bash
   chmod +x docker/run.sh
   ```

2. **Container Not Starting**
   - Ensure Docker is running
   - Check logs: `docker-compose logs`
   - Try rebuilding: `docker-compose build --no-cache`

3. **Rust Tools Not Found**
   - Rebuild the container: `docker-compose build`
   - Check Rust installation: `rustc --version`

## Customization

### Adding System Dependencies

Edit the `Dockerfile` and add packages to the `apt-get install` command.

### Adding Rust Dependencies

Add them to your `Cargo.toml` file as usual.

### Extending the Environment

Customize these files as needed:

- `Dockerfile`: System-level dependencies and configuration
- `docker-compose.yml`: Container configuration and volume mounts
- `.devcontainer/devcontainer.json`: VSCode-specific settings
   cargo build
   
   # Build for release
   cargo build --release
   
   # Run clippy for linting
   cargo clippy -- -D warnings
   
   # Run formatter
   cargo fmt -- --check
   ```

### Local Development

1. **Prerequisites**:
   - Rust (latest stable)
   - Docker (for containerized builds)
   - musl-tools (for static builds)

2. **Build and run**:
   ```bash
   # Build the application
   cargo build
   
   # Run tests
   cargo test
   
   # Build release with MUSL
   cargo build --release --target x86_64-unknown-linux-musl
   ```

## Troubleshooting

### Common Issues

1. **Missing MUSL tools**:
   ```bash
   # On Debian/Ubuntu
   sudo apt-get install musl-tools musl-dev
   ```

2. **Cleaning build artifacts**:
   ```bash
   cargo clean
   ./docker/run.sh clean
   ```

3. **Checking binary compatibility**:
   ```bash
   # Should show "statically linked"
   file target/x86_64-unknown-linux-musl/release/proxmox-vm-manager
   
   # Should show "not a dynamic executable"
   ldd target/x86_64-unknown-linux-musl/release/proxmox-vm-manager
   ```

## CI/CD Integration

The project is set up to work with containerized builds. For CI/CD, you can use the provided `Dockerfile` and `docker/run.sh` script to ensure consistent builds across environments.

Example GitHub Actions workflow:

```yaml
name: Build and Test

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
      
    - name: Build and test
      run: |
        chmod +x docker/run.sh
        ./docker/run.sh musl
        ./target/x86_64-unknown-linux-musl/release/proxmox-vm-manager --version
```
   *Moet tonen: "statically linked"*