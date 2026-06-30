{
  config,
  lib,
  pkgs,
  winpodxPackage,
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

    winpodx = {
      enable = lib.mkEnableOption "WinPodX Windows VM integration";
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
      pkgs.e2fsprogs
    ]
    ++ lib.optionals cfg.winpodx.enable [
      winpodxPackage
      pkgs.usbredir
    ];

    users.users.${mainUser}.extraGroups = [ "podman" ];
  };
}
