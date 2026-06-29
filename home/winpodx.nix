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

    # NOTE: winpodx.toml is NOT managed by home-manager — it's an
    # imperative config written by `winpodx setup` and persisted via
    # impermanence (~/.config/winpodx). Using home.file here would
    # create a read-only Nix store symlink that blocks winpodx setup
    # from writing the real config.
  };
}
