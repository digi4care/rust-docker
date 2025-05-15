# Rust Docker Development Guide

This guide provides detailed information about the Rust Docker development environment and how to use it effectively.

## Development Container

The development container is based on the official Rust Docker image and includes:
- Latest stable Rust toolchain
- Cargo package manager
- Common development tools (git, vim, curl, etc.)
- Rust-analyzer for IDE support
- Cargo watch for automatic rebuilding

## Getting Started

### Starting the Development Environment

```bash
# Start the development container
./docker/run.sh dev

# This will give you a shell inside the container with:
# - Your source code mounted at /workspace
# - All Rust tools available in PATH
# - Proper file permissions for your user
```

### Basic Commands

Inside the development container, you can use standard Cargo commands:

```bash
# Create a new project
cargo new myapp
cd myapp

# Build the project
cargo build

# Run the project
cargo run

# Run tests
cargo test

# Check for warnings
cargo check

# Format code
cargo fmt

# Check code style
cargo clippy
```

## Building for Production

### Building a Release Binary

To build an optimized release binary:

```bash
# Build in release mode
./docker/run.sh build --release

# The binary will be available at:
# target/release/your-binary-name

# To build a static MUSL binary (fully static, no dependencies):
./docker/run.sh musl
```

## Development Workflow

### Using VSCode with Remote-Containers

1. Install the "Remote - Containers" extension in VSCode
2. Open the command palette (Ctrl+Shift+P) and select "Remote-Containers: Reopen in Container"
3. VSCode will build the container and attach to it
4. Install the "rust-analyzer" extension in the container when prompted

### Using Cargo Watch

The development container includes `cargo-watch` for automatic rebuilding:

```bash
# Watch for changes and run tests
cargo watch -x test

# Watch for changes and run the application
cargo watch -x run
```

## Troubleshooting

### Common Issues

1. **Permission Issues**
   - If you get permission errors, try running:
     ```bash
     chmod +x docker/run.sh
     ```

2. **Container Not Starting**
   - Make sure Docker is running
   - Check for any error messages when running `docker ps -a`

3. **Rust Tools Not Found**
   - Try rebuilding the container: `docker-compose build`
   - Check that the Rust toolchain is installed: `rustc --version`

## Customization

### Adding Dependencies

To add system dependencies, edit the `Dockerfile` and add them to the `apt-get install` command.

For Rust dependencies, add them to your `Cargo.toml` file as usual.

### Extending the Environment

You can customize the development environment by modifying:
- `Dockerfile` - For system-level dependencies and configuration
- `docker-compose.yml` - For container configuration and volume mounts
- `.devcontainer/devcontainer.json` - For VSCode-specific settings
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