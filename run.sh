#!/bin/bash
set -e

# Create 'build' directory, don't fail if the directory is already present.
mkdir -p build || true

# Build a raw binary, this should contain exactly 512 bytes.
nasm src/$1/bootloader.asm -f bin -o build/$1.img && \
# Run a quick emulation with this image in a floppy disk.
qemu-system-x86_64 -fda build/$1.img