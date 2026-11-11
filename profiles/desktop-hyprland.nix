{
  lib,
  mainUser,
  ...
}:

{
  features.desktop-hyprland = {
    enable = lib.mkDefault true;
    withUWSM = lib.mkDefault true;
    # Session shell — lucid (the main-line Hyprland shell). The DMS
    # evaluation lives on the dux-shell branch: there this profile flips
    # these two lines (lucid false / dms true) on top of main, nothing
    # else differs — so the testbed stays a single commit over main.
    lucid.enable = lib.mkDefault true;
    dms.enable = lib.mkDefault false;
    greeter = {
      configHome = lib.mkDefault "/home/${mainUser}";
      # Boot into the session behind the shell lock screen (DMS here) —
      # no greeter→session VT flash (see modules/features/desktop-hyprland.nix).
      autoLogin = lib.mkDefault true;
    };
  };
  features.fonts.enable = lib.mkDefault true;
}
