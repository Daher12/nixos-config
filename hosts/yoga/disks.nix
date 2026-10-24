_: # No arguments used in this module
let
  # noatime implies nodiratime; space_cache=v2 and the ssd allocator hint
  # are kernel defaults (the extra flags were dropped 2026-10-24).
  btrfsOpts = [
    "compress-force=zstd:1"
    "noatime"
    "discard=async"
  ];
in
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/nvme0n1";
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
            name = "cryptroot";
            label = "cryptroot";
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = btrfsOpts;
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = btrfsOpts;
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = btrfsOpts;
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
