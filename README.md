
# Rust Development Environment in Docker

A Docker-based development environment for Rust applications. This template provides a complete, isolated Rust development environment with all necessary tools pre-installed, allowing you to develop Rust applications without installing Rust on your host machine.

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/digi4care/rust-docker.git
   cd rust-docker
   ```

2. Start the development environment:
   ```bash
   ./docker/run.sh dev
   ```
   This will give you an interactive shell inside the container with all Rust tools installed.

3. Inside the container, create and run your Rust project:
   ```bash
   cargo new myapp
   cd myapp
   cargo run
   ```

## Features

- Full Rust development environment in Docker
- No Rust installation required on host
- Pre-configured with common development tools
- Supports both development and production builds
- Integrated with VSCode Remote-Containers

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
   git clone https://github.com/digi4care/my-rust-app.git
   cd my-rust-app
   ```

3. For a static MUSL build:
   ```bash
   # Install MUSL target
   rustup target add x86_64-unknown-linux-musl

   # Install musl-tools (Debian/Ubuntu)
   sudo apt-get install musl-tools musl-dev

## Documentation

For detailed documentation, including advanced usage, development workflows, and troubleshooting, please see [DEVELOPER.md](DEVELOPER.md).

## License

MIT License

## License

MIT License

## Author

Chris Engelhard <chris@chrisengelhard.nl>

