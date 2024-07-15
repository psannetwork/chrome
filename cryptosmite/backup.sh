#!/bin/bash

# Check if running as root
if [ $(id -u) -gt 0 ]; then
    echo "Please run $0 as root"
    exit 0
fi

# Define paths and variables
STATEFUL_PART="/mnt/stateful_partition"
ENCSTATEFUL_MNT=$(mktemp -d)
CRYPTSETUP_PATH="/usr/local/bin/cryptsetup_$(arch)"
BACKUP_PATH="/saved_stateful.tar.gz"

# Function to clean up mounts and devices
cleanup() {
    umount "$ENCSTATEFUL_MNT" || :
    ${CRYPTSETUP_PATH} close encstateful || :
    umount "$STATEFUL_PART" || :
    rm -rf "$ENCSTATEFUL_MNT"
}

# Ensure cleanup on exit
trap cleanup EXIT INT

# Create necessary directories and mount stateful partition
mkdir -p "$STATEFUL_PART"
mount -o rw /dev/sda1 "$STATEFUL_PART"
chmod +x /usr/local/bin/cryptsetup_aarch64
chmod +x /usr/local/bin/cryptsetup_x86_64

# Key management (replace with your actual key extraction if needed)
key_ecryptfs() {
    cat <<EOF | base64 -d
p2/YL2slzb2JoRWCMaGRl1W0gyhUjNQirmq8qzMN4Do=
EOF
}

# Set up encstateful
truncate -s "$NEW_ENCSTATEFUL_SIZE" "$STATEFUL_PART"/encrypted.block
ENCSTATEFUL_KEY=$(mktemp)
key_ecryptfs > "$ENCSTATEFUL_KEY"
${CRYPTSETUP_PATH} open --type plain --cipher aes-cbc-essiv:sha256 --key-size 256 --key-file "$ENCSTATEFUL_KEY" "$STATEFUL_PART"/encrypted.block encstateful

# Mount encstateful
mkdir -p "$ENCSTATEFUL_MNT"
mount /dev/mapper/encstateful "$ENCSTATEFUL_MNT"

# Backup the data
echo "Backing up data..."
tar -czf "$BACKUP_PATH" -C "$ENCSTATEFUL_MNT" .
echo "Successfully extracted encstateful data to $BACKUP_PATH! DO NOT SHARE THIS WITH ANYONE as it may contain sensitive information."

# Clean up
cleanup

echo "Re-enrollment data extraction completed."
