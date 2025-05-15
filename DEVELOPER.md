# Development Guide

## Building with MUSL (Static Binary)

### Using Docker (Recommended)

```bash
# Build a static MUSL binary using the provided script
./docker/run.sh musl

# The binary will be available at:
# target/x86_64-unknown-linux-musl/release/proxmox-vm-manager
```

### Manual Build

1. **Install MUSL target** (one-time setup):
   ```bash
   rustup target add x86_64-unknown-linux-musl
   ```

2. **Build the binary**:
   ```bash
   cargo build --release --target x86_64-unknown-linux-musl
   ```

3. **Verify the binary**:
   ```bash
   # Check that it's a static binary
   file target/x86_64-unknown-linux-musl/release/proxmox-vm-manager
   
   # Should show: "statically linked"
   ldd target/x86_64-unknown-linux-musl/release/proxmox-vm-manager
   ```

## Development Workflow

### Using Docker (Recommended)

1. Start the development container:
   ```bash
   ./docker/run.sh dev
   ```
   This gives you an interactive shell with all dependencies installed.

2. Inside the container, you can:
   ```bash
   # Run tests
   cargo test
   
   # Build in debug mode
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