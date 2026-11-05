{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.desktop.dms;

  # First-boot defaults for ~/.config/dms/settings.json. Deliberately tiny:
  # DMS's config.d drop-in merge order vs the Settings UI's settings.json
  # write-back is unverified, so the seed is installed ONCE (activation
  # below) and everything the UI writes afterwards stays authoritative —
  # the same seed-once contract lucid's keybinds.json uses. Bar/clock/
  # schedule tuning happens live in DMS Settings, then gets harvested back
  # into this seed once the look is right.
  dmsSettingsSeed = pkgs.writeText "dms-settings-seed.json" (
    builtins.toJSON {
      currentThemeName = "custom";
      customThemeFile = "${config.home.homeDirectory}/.config/dms/themes/grayscale/theme.json";
    }
  );
in
{
  options.desktop.dms = {
    enable = lib.mkEnableOption "DMS (dux-shell) desktop shell on the Hyprland session — seeds settings + the grayscale theme (the dms user service, PAM and runtime deps are wired NixOS-side in modules/features/desktop-hyprland.nix)";
  };

  config = lib.mkIf cfg.enable {
    # Static grayscale palette ported from lucid's theme pair
    # (home/lucid-themes/grayscale — dark face → "dark", light face →
    # "light"). Store symlink is fine: DMS only READS customThemeFile, and
    # switching to wallpaper-dynamic matugen later is one Settings toggle
    # (currentThemeName back to an auto preset).
    xdg.configFile."dms/themes/grayscale/theme.json".source = ./dms-themes/grayscale/theme.json;

    # Install the seed only when no settings.json exists yet (fresh state /
    # fresh impermanence). Never touches a settings.json DMS has written —
    # UI edits survive every rebuild.
    home.activation.seedDmsSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "$HOME/.config/dms/settings.json" ]; then
        mkdir -p "$HOME/.config/dms"
        install -Dm0644 ${dmsSettingsSeed} "$HOME/.config/dms/settings.json"
      fi
    '';
  };
}
