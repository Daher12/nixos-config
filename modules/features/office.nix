{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.office;

  compatibilityFonts = with pkgs; [
    liberation_ttf
    caladea
    carlito
  ];

  profileSeedFile =
    if cfg.profileSeed == null then null else cfg.profileSeed + "/registrymodifications.xcu";

  installProfile =
    if profileSeedFile == null then
      null
    else
      pkgs.writeShellScriptBin "libreoffice-install-profile" ''
        set -euo pipefail

        target="$HOME/.config/libreoffice/4/user"
        mkdir -p "$target"

        if [ -e "$target/registrymodifications.xcu" ] && [ "${
          if cfg.overwriteExistingProfile then "1" else "0"
        }" != "1" ]; then
          echo "LibreOffice profile already exists at $target/registrymodifications.xcu"
          echo "Refusing to overwrite. Set features.office.overwriteExistingProfile = true"
          echo "or move the existing file out of the way."
          exit 1
        fi

        cp ${lib.escapeShellArg profileSeedFile} "$target/registrymodifications.xcu"
        echo "Installed LibreOffice starter profile to $target"
      '';
in
{
  options.features.office = {
    enable = lib.mkEnableOption "LibreOffice-based office workstation defaults";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.libreoffice;
      description = "LibreOffice package to install.";
    };

    vclPlugin = lib.mkOption {
      type = lib.types.enum [
        "gtk3"
        "qt6"
        "gen"
      ];
      default = "gtk3";
      description = ''
        Preferred LibreOffice VCL backend.
        Use gtk3 as the default for GNOME hosts.
        Use qt6 if you later want tighter Plasma integration.
      '';
    };

    installCompatibilityFonts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install metric-compatible fonts for better Office document fidelity.";
    };

    overwriteExistingProfile = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow libreoffice-install-profile to overwrite an existing user profile.";
    };

    profileSeed = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = ./office-profile;
      description = ''
        Directory containing an exported LibreOffice profile seed.
        At minimum it must include registrymodifications.xcu.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional office-adjacent packages to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = profileSeedFile == null || builtins.pathExists profileSeedFile;
        message = "features.office.profileSeed must contain registrymodifications.xcu";
      }
    ];

    features.fonts.enable = lib.mkDefault true;

    environment.sessionVariables.SAL_USE_VCLPLUGIN = lib.mkDefault cfg.vclPlugin;
    environment.systemPackages = [
      cfg.package
    ]
    ++ lib.optionals cfg.installCompatibilityFonts compatibilityFonts
    ++ lib.optionals (installProfile != null) [ installProfile ]
    ++ cfg.extraPackages;

    environment.etc = lib.mkIf (profileSeedFile != null) {
      "skel/.config/libreoffice/4/user/registrymodifications.xcu".source = profileSeedFile;
    };
  };
}
