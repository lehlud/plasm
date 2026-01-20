# Copilot Setup Instructions

This file provides instructions for setting up the development environment for the Plasm compiler.

## Required Tools

### 1. Dart SDK (3.0 or later)

The Dart SDK is required to build and test the Plasm compiler.

**Installation:**
```bash
# Download and install Dart SDK
wget https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip
unzip dartsdk-linux-x64-release.zip -d $HOME
export PATH="$HOME/dart-sdk/bin:$PATH"

# Verify installation
dart --version

# Get dependencies
cd /home/runner/work/plasm/plasm
dart pub get
```

### 2. Node.js (20.x or later)

Node.js is required for running WASI tests and the runtime integration.

**Installation:**
```bash
# Node.js is typically pre-installed in GitHub Actions
node --version

# If not installed:
# curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
# sudo apt-get install -y nodejs
```

### 3. WABT (WebAssembly Binary Toolkit)

WABT provides `wat2wasm` and other tools for working with WebAssembly.

**Installation:**
```bash
# Download and install WABT
wget https://github.com/WebAssembly/wabt/releases/download/1.0.34/wabt-1.0.34-ubuntu.tar.gz
tar xzf wabt-1.0.34-ubuntu.tar.gz
export PATH="$PWD/wabt-1.0.34/bin:$PATH"

# Verify installation
wat2wasm --version
```

## Running Tests

Once all tools are installed:

```bash
# Run all tests
dart test

# Run specific test file
dart test test/plasm_test.dart

# Run with verbose output
dart test --reporter expanded
```

## Building the Compiler

```bash
# Compile a Plasm program
dart run bin/plasm.dart examples/simple_run.plasm output.wasm

# Compile and run
dart run bin/plasm.dart run examples/simple_run.plasm
```

## Environment Setup Script

For convenience, create a `setup.sh` script:

```bash
#!/bin/bash
set -e

# Install Dart SDK
if ! command -v dart &> /dev/null; then
    echo "Installing Dart SDK..."
    wget -q https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip
    unzip -q dartsdk-linux-x64-release.zip -d $HOME
    export PATH="$HOME/dart-sdk/bin:$PATH"
    echo 'export PATH="$HOME/dart-sdk/bin:$PATH"' >> ~/.bashrc
fi

# Install WABT
if ! command -v wat2wasm &> /dev/null; then
    echo "Installing WABT..."
    wget -q https://github.com/WebAssembly/wabt/releases/download/1.0.34/wabt-1.0.34-ubuntu.tar.gz
    tar xzf wabt-1.0.34-ubuntu.tar.gz
    export PATH="$PWD/wabt-1.0.34/bin:$PATH"
    echo 'export PATH="$PWD/wabt-1.0.34/bin:$PATH"' >> ~/.bashrc
fi

# Get Dart dependencies
dart pub get

echo "Setup complete! Run 'dart test' to run tests."
```

Make it executable: `chmod +x setup.sh`

## CI/CD Integration

For GitHub Actions, add this to your workflow:

```yaml
- name: Setup Dart
  uses: dart-lang/setup-dart@v1
  
- name: Install WABT
  run: |
    wget https://github.com/WebAssembly/wabt/releases/download/1.0.34/wabt-1.0.34-ubuntu.tar.gz
    tar xzf wabt-1.0.34-ubuntu.tar.gz
    echo "$PWD/wabt-1.0.34/bin" >> $GITHUB_PATH
    
- name: Get dependencies
  run: dart pub get
  
- name: Run tests
  run: dart test
```
