{
  lib,
  mainUser,
  ...
}:

{
  features.desktop-hyprland = {
    enable = lib.mkDefault true;
    withUWSM = lib.mkDefault true;
    # lucid-testing branch: Lucid replaces the DMS user-session shell
    # (options in modules/features/desktop-hyprland.nix; deployment in
    # home/lucid.nix). Flip both back for a DMS rebuild — dms.enable=true,
    # lucid.enable=false.
    dms.enable = lib.mkDefault false;
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
