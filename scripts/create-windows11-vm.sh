#!/usr/bin/env bash
set -euo pipefail

# Windows 11 VM Creation for Single Integrated GPU
# Optimized for iTunes + Office workloads

VM_NAME="windows11"
VM_MAC="52:54:00:00:00:01"
VM_CPUS="4"
VM_MEMORY="8192"  # 8GB minimum for Windows 11
DISK_SIZE="80"    # 80GB
DISK_PATH="$HOME/.local/share/libvirt/images/${VM_NAME}.qcow2"
ISO_PATH="$HOME/Downloads/Win11.iso"
VIRTIO_ISO="$HOME/Downloads/virtio-win.iso"

echo "Windows 11 VM Configuration"
echo "============================"
echo "Name: $VM_NAME"
echo "CPUs: $VM_CPUS"
echo "Memory: ${VM_MEMORY}MB"
echo "Disk: ${DISK_SIZE}GB"
echo ""

# Verify prerequisites
if [ ! -f "$ISO_PATH" ]; then
    echo "❌ Windows 11 ISO not found: $ISO_PATH"
    echo "Download from: https://www.microsoft.com/software-download/windows11"
    exit 1
fi

if [ ! -f "$VIRTIO_ISO" ]; then
    echo "⚠ VirtIO drivers ISO not found"
    echo "Run: get-virtio-win"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Create disk image
mkdir -p "$(dirname "$DISK_PATH")"
if [ ! -f "$DISK_PATH" ]; then
    echo "Creating disk image..."
    qemu-img create -f qcow2 -o preallocation=metadata "$DISK_PATH" "${DISK_SIZE}G"
fi

# Create VM
virt-install \
    --name "$VM_NAME" \
    --memory "$VM_MEMORY" \
    --vcpus "$VM_CPUS",sockets=1,cores="$VM_CPUS",threads=1 \
    --cpu host-passthrough,cache.mode=passthrough \
    --machine q35 \
    --boot uefi,loader=/run/libvirt/nix-ovmf/OVMF_CODE.fd,loader_ro=yes,loader_type=pflash,nvram_template=/run/libvirt/nix-ovmf/OVMF_VARS.fd \
    --features smm.state=on \
    --clock offset=localtime,rtc_tickpolicy=catchup \
    --disk path="$DISK_PATH",format=qcow2,bus=virtio,cache=writeback,io=threads,discard=unmap \
    --network network=default,model=virtio,mac="$VM_MAC" \
    --graphics spice,listen=127.0.0.1,gl.enable=yes,gl.rendernode=/dev/dri/renderD128 \
    --video virtio \
    --channel spicevmc,target_type=virtio,name=com.redhat.spice.0 \
    --channel unix,target_type=virtio,name=org.qemu.guest_agent.0 \
    --tpm backend.type=emulator,backend.version=2.0,model=tpm-tis \
    --rng /dev/urandom \
    --controller type=scsi,model=virtio-scsi \
    --controller type=virtio-serial \
    --cdrom "$ISO_PATH" \
    $([ -f "$VIRTIO_ISO" ] && echo "--disk path=$VIRTIO_ISO,device=cdrom,readonly=on") \
    --os-variant win11 \
    --noautoconsole

echo ""
echo "✓ VM created successfully"
echo ""
echo "Next steps:"
echo "  1. Connect: virt-manager (or virt-viewer $VM_NAME)"
echo "  2. Install Windows 11"
echo "  3. During installation, load VirtIO drivers for disk/network"
echo "  4. After installation:"
echo "     - Install VirtIO guest tools"
echo "     - Enable RDP (Settings > System > Remote Desktop)"
echo "     - Configure Windows user account"
echo "  5. Configure WinApps: winapps-configure"
echo "  6. Test setup: winapps-setup"
