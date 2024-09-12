#!/bin/bash

CHROOT_DIR="/usr/local/ubuntu-focal-arm64"

function error_exit {
    echo "$1" >&2
    exit 1
}

function unmount_chroot {
    echo "Unmounting chroot directories..."

    if mountpoint -q "$CHROOT_DIR/dev"; then
        sudo umount "$CHROOT_DIR/dev" || error_exit "Failed to unmount /dev."
    fi

    if mountpoint -q "$CHROOT_DIR/proc"; then
        sudo umount "$CHROOT_DIR/proc" || error_exit "Failed to unmount /proc."
    fi

    if mountpoint -q "$CHROOT_DIR/sys"; then
        sudo umount "$CHROOT_DIR/sys" || error_exit "Failed to unmount /sys."
    fi
}

function delete_chroot {
    echo "Deleting chroot environment..."

    if [ -d "$CHROOT_DIR" ]; then
        echo "Removing chroot directory at $CHROOT_DIR"
        sudo rm -rf "$CHROOT_DIR" || error_exit "Failed to remove chroot directory."
    else
        echo "Chroot directory does not exist. Nothing to delete."
    fi
}

function main {
    if [ ! -d "$CHROOT_DIR" ]; then
        error_exit "Chroot directory $CHROOT_DIR does not exist."
    fi

    unmount_chroot
    delete_chroot
    echo "Chroot environment deleted successfully."
}

main
