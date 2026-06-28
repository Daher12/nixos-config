{
  config,
  lib,
  pkgs,
  mainUser,
  ...
}:

let
  cfg = config.features.podman;
in
{
  options.features.podman = {
    enable = lib.mkEnableOption "Podman container management";

    dockerCompat = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Expose a docker CLI compatibility wrapper so tooling that expects
        the docker CLI (e.g. WinPodX) can find it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;
      inherit (cfg) dockerCompat;
      defaultNetwork.settings.dns_enabled = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    environment.systemPackages = [
      pkgs.e2fsprogs # chattr for btrfs +C (nodatacow) on container storage
    ];

    users.users.${mainUser}.extraGroups = [ "podman" ];
  };
}
