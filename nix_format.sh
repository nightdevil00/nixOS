#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EFI_SIZE_MB=2048

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root (use sudo)"
        exit 1
    fi
}

list_disks() {
    echo "Available disks:"
    echo ""
    lsblk -o NAME,SIZE,TYPE,VENDOR,MODEL | grep -E "disk$|NAME"
    echo ""
}

select_disk() {
    echo "Enter the disk to format (e.g., sda, nvme0n1):"
    read -r DISK
    
    if [[ ! -b "/dev/$DISK" ]]; then
        echo "Error: /dev/$DISK does not exist"
        exit 1
    fi
    
    DISK_PATH="/dev/$DISK"
    echo "Selected disk: $DISK_PATH"
}

confirm_destructive() {
    echo ""
    echo "WARNING: This will ERASE ALL DATA on $DISK_PATH"
    echo "Type 'yes' to confirm:"
    read -r CONFIRM
    
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Aborted"
        exit 1
    fi
}

partition_disk() {
    echo ""
    echo "Creating partitions..."
    
    parted --script "$DISK_PATH" -- \
        mklabel gpt \
        mkpart ESP fat32 1MiB "${EFI_SIZE_MB}MiB" \
        set 1 esp on \
        mkpart ROOT ext4 "${EFI_SIZE_MB}MiB" 100% \
        print
    
    if [[ "$DISK" == nvme* ]]; then
        EFI_PART="${DISK_PATH}p1"
        ROOT_PART="${DISK_PATH}p2"
    else
        EFI_PART="${DISK_PATH}1"
        ROOT_PART="${DISK_PATH}2"
    fi
    
    echo "EFI partition: $EFI_PART"
    echo "ROOT partition: $ROOT_PART"
}

format_partitions() {
    echo ""
    echo "Formatting partitions..."
    
    mkfs.fat -F 32 "$EFI_PART"
    echo "EFI partition formatted as FAT32"
    
    mkfs.ext4 -F "$ROOT_PART"
    echo "ROOT partition formatted as EXT4"
}

get_uuids() {
    echo ""
    echo "Getting UUIDs..."
    
    EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
    ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
    
    echo "EFI UUID: $EFI_UUID"
    echo "ROOT UUID: $ROOT_UUID"
}

update_hardware_config() {
    echo ""
    echo "Updating hardware-configuration.nix with new UUIDs..."
    
    HARDWARE_CONFIG="$SCRIPT_DIR/hardware-configuration.nix"
    
    sed -i "s|CA5E-B0BB|$EFI_UUID|" "$HARDWARE_CONFIG"
    sed -i "s|ff98e231-d728-4915-8b0c-aaa79f6721a3|$ROOT_UUID|" "$HARDWARE_CONFIG"
    
    echo "hardware-configuration.nix updated"
}

main() {
    echo "=== NixOS Disk Formatter ==="
    echo ""
    
    check_root
    list_disks
    select_disk
    confirm_destructive
    
    partition_disk
    format_partitions
    get_uuids
    update_hardware_config
    
    echo ""
    echo "=== Formatting complete! ==="
    echo ""
    echo "Next steps:"
    echo "1. Mount the partitions:"
    echo "   mount $ROOT_PART /mnt"
    echo "   mkdir -p /mnt/boot/efi"
    echo "   mount $EFI_PART /mnt/boot/efi"
    echo "2. Run the installer:"
    echo "   sudo ./install.sh"
}

main "$@"
