{ ... }: # No lib arg needed
let
  btrfsOpts = [
    "compress-force=zstd:1"
    "noatime"
    "nodiratime"
    "discard=async"
    "space_cache=v2"
    "ssd"
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
              mountOptions = [ "fmask=0077" "dmask=0077" ];
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
