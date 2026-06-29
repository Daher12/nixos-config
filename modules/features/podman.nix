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

      apps = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "file-explorer"
          "microsoft-edge"
          "tiptoi-manager"
          "itunes"
        ];
        description = "WinPodX apps visible in the Linux desktop menu";
      };
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
    ];

    users.users.${mainUser}.extraGroups = [ "podman" ];

    systemd.services.winpodx-apps = lib.mkIf cfg.winpodx.enable {
      description = "Configure WinPodX visible apps";
      wantedBy = [ "multi-user.target" ];
      path = [ winpodxPackage ];
      serviceConfig = {
        Type = "oneshot";
        User = mainUser;
      };
      script = ''
        sleep 30
        winpodx app refresh
        winpodx app list | tail -n +4 | awk '{print $1}' | while read name; do
          winpodx app hide "$name"
        done
        ${lib.concatStringsSep "\n" (map (app: "winpodx app show ${app}") cfg.winpodx.apps)}
      '';
    };
  };
}
