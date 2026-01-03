#!/usr/bin/env bash
set -euo pipefail

# Windows 11 VM Creation for NixOS (Optimized)
# Requires: 'virtualization' module enabled with OVMFFull and virtio-win packages

VM_NAME="windows11"
VM_MAC="52:54:00:00:00:01"
VM_CPUS="4"
VM_MEMORY="8192"  # 8GB minimum for smooth Win11 + Office
DISK_SIZE="80"    # 80GB

# NOTE: This is a ONE-TIME provisioning script.
# The values above MUST match features.virtualization.windows11.{mac,name,ip}
# if you've customized them in your NixOS configuration.
# Default module values: mac=52:54:00:00:00:01, name=windows11, ip=192.168.122.10

# PREREQUISITES:
# 1. Enable virtualization module: features.virtualization.enable = true
# 2. Enable Windows 11 support: features.virtualization.windows11.enable = true
# 3. Rebuild NixOS: sudo nixos-rebuild switch --flake .#<hostname>
# 4. Place Windows 11 ISO at ~/Downloads/Win11.iso

# PATHS
# Use the system libvirt directory to inherit the '+C' (No_COW) attribute 
# defined in virtualization.nix. This prevents massive fragmentation on Btrfs.
DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"

# Windows 11 ISO (User must provide this)
ISO_PATH="$HOME/Downloads/Win11.iso"

# VirtIO Drivers (Provided by NixOS package 'virtio-win')
# This path exists because virtualization.nix adds 'virtio-win' to systemPackages
# when includeGuestTools = true (default when windows11.enable = true)
VIRTIO_ISO="/run/current-system/sw/share/virtio-win/virtio-win.iso"

echo "Windows 11 VM Configuration"
echo "============================"
echo "Name:   $VM_NAME"
echo "CPUs:   $VM_CPUS"
echo "Memory: ${VM_MEMORY}MB"
echo "Disk:   $DISK_PATH (${DISK_SIZE}GB)"
echo "Driver: $VIRTIO_ISO"
echo ""

# 1. Verify ISOs
if [ ! -f "$ISO_PATH" ]; then
    echo "❌ Windows 11 ISO not found at: $ISO_PATH"
    echo "Please download it from Microsoft and place it in ~/Downloads/"
    exit 1
fi

if [ ! -f "$VIRTIO_ISO" ]; then
    echo "⚠  VirtIO ISO not found in system packages."
    echo "   Ensure features.virtualization.windows11.enable = true and rebuild."
    echo "   Checking fallback..."
    VIRTIO_ISO="$HOME/Downloads/virtio-win.iso"
    if [ ! -f "$VIRTIO_ISO" ]; then
        echo "❌ No driver ISO found. Ensure 'virtio-win' is in your system packages."
        exit 1
    fi
fi

# 2. Create Disk Image (Requires Sudo for /var/lib/libvirt/images)
if [ ! -f "$DISK_PATH" ]; then
    echo "Creating disk image (requires sudo for /var/lib/libvirt)..."
    # preallocation=metadata is excellent for qcow2 on btrfs (fast creation, less frag)
    sudo qemu-img create -f qcow2 -o preallocation=metadata "$DISK_PATH" "${DISK_SIZE}G"
    
    # Set permissions so libvirt (root/qemu) can use it, but keeping it secure
    sudo chown root:kvm "$DISK_PATH"
    sudo chmod 660 "$DISK_PATH"
else
    echo "✔ Disk image already exists."
fi

# 3. Create VM
# Note: We use --boot uefi to let libvirt automatically pick the OVMFFull firmware 
# from the system descriptors.
echo "Defining VM..."
virt-install \
    --name "$VM_NAME" \
    --memory "$VM_MEMORY" \
    --vcpus "$VM_CPUS",sockets=1,cores="$VM_CPUS",threads=1 \
    --cpu host-passthrough,cache.mode=passthrough \
    --machine q35 \
    --boot uefi \
    --features smm.state=on \
    --clock offset=localtime,rtc_tickpolicy=catchup \
    --disk path="$DISK_PATH",bus=virtio,cache=none,discard=unmap \
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
    --disk path="$VIRTIO_ISO",device=cdrom,readonly=on \
    --os-variant win11 \
    --noautoconsole

echo ""
echo "✓ VM created successfully"
echo ""
echo "Installation Tips:"
echo "1. Connect: virt-manager"
echo "2. Install Windows: Select 'Custom Install'"
echo "3. Drives missing? Click 'Load Driver' -> CDROM (virtio) -> amd64 -> w11"
echo "4. Network missing? Install NetKVM driver later or during setup"
echo "5. After Install: Run virtio-win-guest-tools.exe from the CDROM"
