{
  config,
  lib,
  winpodxPackage,
  ...
}:

let
  cfg = config.programs.winpodx;
in
{
  options.programs.winpodx = {
    enable = lib.mkEnableOption "WinPodX — seamless Windows app integration via FreeRDP RemoteApp + dockur/windows";

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra TOML lines appended to winpodx.toml";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = winpodxPackage != null;
        message = "winpodxPackage must be provided via extraSpecialArgs";
      }
    ];

    home.packages = [
      winpodxPackage
    ];

    # Uses home.file (not xdg.configFile) so the file is a mutable copy
    # that winpodx setup can overwrite during first-run provisioning.
    home.file.".config/winpodx/winpodx.toml".text = ''
      # WinPodX configuration
      # This skeleton is overwritten by `winpodx setup` on first run.
      # Add custom settings below this line.
    ''
    + cfg.extraConfig;
  };
}
