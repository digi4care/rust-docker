
# Rust Development Environment in Docker

A Docker-based Rust development environment that allows you to build and run Rust applications without installing Rust on your host machine. This template provides a complete, isolated Rust development environment with all necessary tools pre-installed.

## Features

- Full Rust development environment without host installation
- Pre-configured with common development tools
- Easy to use with simple Docker commands
- Supports both development and production builds
- Includes tools for code formatting, linting, and testing

## Getting Started

### Prerequisites

- Docker installed on your system
- Basic knowledge of Docker and Rust

### Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/rust-docker.git
   cd rust-docker
   ```

2. Build and run the development container:
   ```bash
   # Start the development environment
   ./docker/run.sh dev
   ```
   This will give you an interactive shell inside the container with all Rust tools installed.

3. Inside the container, you can use standard Cargo commands:
   ```bash
   # Create a new project
   cargo new myapp
   cd myapp
   
   # Build and run
   cargo run
   ```

## Development Workflow

### Using the Development Container

The development container comes with:
- Rust toolchain (stable, nightly)
- Common development tools (git, vim, curl, etc.)
- Rust-analyzer for IDE support
- Cargo watch for automatic rebuilding

### Building for Production

To build a release version of your application:

```bash
# Build a release binary
./docker/run.sh build --release

# The binary will be available in the target/release directory

   # Run the application
   ./docker/run.sh run list

   # Or build a static MUSL binary (compiles in a Docker container)
   ./docker/run.sh musl
   ```

### Option 3: Manual Installation (for development)

**Requirements:**
- Rust toolchain (v1.70+)
- musl-tools (for static builds)
- build-essential / make / pkg-config / ssl-dev (for some dependencies)

1. Install Rust (if not already installed):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/digi4care/proxmox-vm-manager.git
   cd proxmox-vm-manager
   ```

3. For a static MUSL build:
   ```bash
   # Install MUSL target
   rustup target add x86_64-unknown-linux-musl

   # Install musl-tools (Debian/Ubuntu)
   sudo apt-get install musl-tools musl-dev

   # Build with MUSL
   cargo build --release --target x86_64-unknown-linux-musl

   # The binary will be at:
   # target/x86_64-unknown-linux-musl/release/proxmox-vm-manager
   ```

## Usage

### List all VMs/templates
```bash
# Using Docker
docker run -it --rm -v $(pwd)/config:/app/config proxmox-vm-manager list

# Or using the run script
./docker/run.sh run list

# Or with the binary directly
./target/x86_64-unknown-linux-musl/release/proxmox-vm-manager list
```

Example output:
```
ID      Type       Name
------------------------------
100     VM         ubuntu-server
101     Template   debian-template
102     VM         docker-host
```

### Remove VMs/templates
```bash
# Using Docker
docker run -it --rm -v $(pwd)/config:/app/config proxmox-vm-manager 100 101 102

# Or using the run script
./docker/run.sh run 100 101 102

# Or with the binary directly
./target/x86_64-unknown-linux-musl/release/proxmox-vm-manager 100 101 102
```

## Development

### Development Workflow

1. Start the development container:
   ```bash
   ./docker/run.sh dev
   ```
   This will give you an interactive shell with all dependencies installed.

2. Build and test your changes:
   ```bash
   cargo build
   cargo test
   ```

3. Build a release version:
   ```bash
   # Regular build
   ./docker/run.sh build

   # Or build a static MUSL binary
   ./docker/run.sh musl
   ```

## Requirements

- Proxmox VE environment
- `qm` command available (Proxmox CLI tools)
- Root or appropriate privileges for VM management

## Version History

- v2.17.5 (2025-05-15):
  - Toegevoegd: Optionele schijfvergroting bij het klonen van VMs
  - Toegevoegd: Ondersteuning voor `disklabel` en `diskspace` in configuratie
  - Verbeterd: Betere foutafhandeling bij schijfvergroting
  - Updated: Afhankelijkheden bijgewerkt naar nieuwste versies
  - Fixed: Docker build proces verbeterd voor betere compatibiliteit
- v2.16.0 (2024-03-20):
  - Toegevoegd: Docker ondersteuning voor eenvoudige implementatie
  - Toegevoegd: Statische MUSL builds voor betere compatibiliteit
  - Verbeterd: Documentatie bijgewerkt met nieuwe installatie-instructies
- v1.1.0 (2023-11-15): Toegevoegd: Lijstfunctionaliteit voor VMs/templates
- v1.0.0 (2023-11-01): Eerste release met verwijderfunctionaliteit

## License

MIT License

## Author

Chris Engelhard <chris@chrisengelhard.nl>

