#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/etc/nixos"
BACKUP_DIR="${TARGET_DIR}.backup.$(date +%Y%m%d_%H%M%S)"

echo "=== NixOS Configuration Installer ==="
echo ""

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    echo "Checking dependencies..."
    
    if ! command -v nix &> /dev/null; then
        echo "Error: nix is not installed"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        echo "Error: git is not installed"
        exit 1
    fi
    
    echo "Dependencies OK"
}

backup_existing() {
    if [[ -d "$TARGET_DIR" ]]; then
        echo "Backing up existing config to: $BACKUP_DIR"
        cp -r "$TARGET_DIR" "$BACKUP_DIR"
    fi
}

copy_config_files() {
    echo "Copying configuration files to $TARGET_DIR..."
    
    mkdir -p "$TARGET_DIR"
    
    cp "$SCRIPT_DIR/configuration.nix" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/hardware-configuration.nix" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/home.nix" "$TARGET_DIR/"
    
    if [[ -d "$SCRIPT_DIR/config" ]]; then
        rm -rf "$TARGET_DIR/config"
        cp -r "$SCRIPT_DIR/config" "$TARGET_DIR/"
    fi
    
    echo "Files copied successfully"
}

build_system() {
    echo ""
    echo "Building NixOS configuration..."
    echo ""
    
    cd "$TARGET_DIR"
    
    nixos-rebuild switch --flake .#default --impure
}

main() {
    check_root
    check_dependencies
    backup_existing
    copy_config_files
    build_system
    
    echo ""
    echo "=== Installation complete! ==="
    echo "Your system has been configured. Please reboot if needed."
}

main "$@"
