# Disk-overflow swapfile, shared by both laptops.
#
# Why disk swap at all: the fleet learned on yoga that zram-only swap +
# oomd's ManagedOOMSwap=kill ends in killed sessions, not slowness. The
# disk file only fills once zram (priority 10) is exhausted. Priority is
# left unset -> the kernel assigns a negative one, so the file always
# sorts BELOW zram. NixOS creates the file via mkswapfile (NOCOW-safe on
# btrfs); hosts own the size and any location rationale (hibernation
# offset bookkeeping lives in hosts/yoga, not here).

{
  config,
  lib,
  ...
}:

let
  cfg = config.features.swapfile;
in
{
  options.features.swapfile = {
    enable = lib.mkEnableOption "disk overflow swapfile below zram";

    sizeMiB = lib.mkOption {
      type = lib.types.int;
      default = 8 * 1024;
      description = "Swapfile size in MiB";
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/swap/swapfile";
      description = "Swapfile path; its parent directory must be persisted under impermanence";
    };
  };

  config = lib.mkIf cfg.enable {
    swapDevices = [
      {
        inherit (cfg) device;
        size = cfg.sizeMiB;
      }
    ];
  };
}
