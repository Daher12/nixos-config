# Declarative disk layout (disko). scripts/install.sh picks this up automatically
# (disko --mode destroy,format,mount) — that path wipes the disk.
#
# Filesystem choice: ext4 (deliberately NOT btrfs like yoga).
# - Dual-core Broadwell + SATA M.2: ext4 has the lowest journaling/CPU overhead;
#   btrfs CoW + zstd compression would trade scarce CPU cycles for I/O on a
#   slow SATA link, and adds scrub/balance maintenance.
# - features.impermanence is btrfs-only and stays disabled here, so btrfs would
#   only buy snapshots — NixOS generation rollback at the bootloader already
#   covers system rollback, filesystem-independent.
# - Simplest recovery story (fsck.ext4) for keeping an old machine alive.
#
# Mounting goes by GPT partlabel (ESP, cryptroot). A fresh install.sh run
# creates those labels itself (disko); adopting a pre-existing install without
# reinstalling instead requires a non-destructive relabel first — recipe in
# git history (this file, pre-2026-10).
{
  disko.devices = {
    disk.main = {
      type = "disk";
      # E7450: SATA M.2 SSD (ahci + sd_mod in the initrd, no NVMe). Only used
      # by disko at format time; runtime mounts go by /dev/disk/by-partlabel.
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            label = "ESP";
            name = "ESP";
            size = "2G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0077"
                "dmask=0077"
              ];
            };
          };
          crypt = {
            label = "cryptroot";
            name = "crypt";
            size = "100%";
            content = {
              type = "luks";
              # Mapper name matches the pre-disko install (/dev/mapper/nixos).
              name = "nixos";
              # TRIM pass-through: features.filesystem (ext4 → fstrim enabled)
              # discards through dm-crypt only with this flag set.
              settings.allowDiscards = true;
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [
                  "noatime"
                  "commit=30"
                ];
              };
            };
          };
        };
      };
    };
  };
}
