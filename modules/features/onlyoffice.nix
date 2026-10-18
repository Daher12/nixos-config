{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.onlyoffice;
in
{
  options.features.onlyoffice = {
    enable = lib.mkEnableOption "ONLYOFFICE Desktop Editors";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.onlyoffice-desktopeditors;
      description = "ONLYOFFICE Desktop Editors package to install.";
    };

    installCompatibilityFonts = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install a minimal compatibility font for better substitution with
        Microsoft-oriented Office documents.
      '';
    };

    enableSharedFonts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Nudge the shared repo font feature on with mkDefault. When disabled,
        this module stays silent and does not contribute any definition to
        features.fonts.enable.
      '';
    };

    cursorSize = lib.mkOption {
      type = lib.types.int;
      default = 64;
      description = ''
        XCURSOR_SIZE onlyoffice-desktopeditors is launched with, injected in
        its own .desktop wrapper. Deliberately NOT exported globally: uwsm's
        env preloader sources /etc/profile last, so a
        environment.sessionVariables export beat home/theme.nix's smaller
        XCURSOR_SIZE for the whole session and made the cursor oversized on
        the boot lock screen (live-verified 2026-10-18).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    features.fonts.enable = lib.mkIf cfg.enableSharedFonts (lib.mkDefault true);

    # The theme module (home/theme.nix) owns XCURSOR_SIZE for the session
    # (32 on yoga); the bigger ONLYOFFICE cursor is scoped to this app only.
    #
    # The upstream .desktop entry hardcodes the unwrapped store path in Exec
    # (main entry + all --new:* actions), so a plain symlinkJoin relink would
    # still exec the stock binary. Wrap the binary and rewrite the Exec lines
    # in a single derivation instead.
    environment.systemPackages =
      let
        bigCursor =
          pkgs.runCommand "onlyoffice-desktopeditors-cursor${toString cfg.cursorSize}"
            {
              nativeBuildInputs = [ pkgs.makeWrapper ];
            }
            ''
              mkdir -p $out/bin $out/share/applications
              makeWrapper ${cfg.package}/bin/onlyoffice-desktopeditors \
                $out/bin/onlyoffice-desktopeditors \
                --inherit-argv0 \
                --set XCURSOR_SIZE ${toString cfg.cursorSize}
              for d in ${cfg.package}/share/*; do
                [ "$(basename "$d")" = applications ] && continue
                ln -s "$d" "$out/share/$(basename "$d")"
              done
              for f in ${cfg.package}/share/applications/*.desktop; do
                sed "s|${cfg.package}/bin/onlyoffice-desktopeditors|$out/bin/onlyoffice-desktopeditors|g" \
                  "$f" > "$out/share/applications/$(basename "$f")"
              done
            '';
      in
      [
        bigCursor
      ];

    fonts.packages = lib.optionals cfg.installCompatibilityFonts [
      pkgs.liberation_ttf
    ];
  };
}
