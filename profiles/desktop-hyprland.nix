{
  lib,
  mainUser,
  ...
}:

{
  features.desktop-hyprland = {
    enable = lib.mkDefault true;
    withUWSM = lib.mkDefault true;
    # Lucid is the desktop shell (options in
    # modules/features/desktop-hyprland.nix; deployment in home/lucid.nix).
    # DankGreeter stays for the greeter; the DMS user-session shell was
    # removed 2026-09-27 (rollback: dms-caelestia-look@4b2f965 in history).
    lucid.enable = lib.mkDefault true;
    greeter = {
      configHome = lib.mkDefault "/home/${mainUser}";
      # Boot into the session behind the shell lock screen (lucid here) —
      # no greeter→session VT flash (see modules/features/desktop-hyprland.nix).
      autoLogin = lib.mkDefault true;
    };
  };
  features.fonts.enable = lib.mkDefault true;
}
