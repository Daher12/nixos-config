{
  lib,
  mainUser,
  ...
}:

{
  features.desktop-hyprland = {
    enable = lib.mkDefault true;
    withUWSM = lib.mkDefault true;
    # Session shell — DUX-SHELL EVAL BRANCH: DMS (DankMaterialShell
    # rebranded, modules/features/desktop-hyprland.nix + home/dms.nix)
    # replaces lucid here. lucid stays fully in the tree — flipping these
    # two lines back (lucid true / dms false) restores the main-branch
    # shell after `git switch main`.
    lucid.enable = lib.mkDefault false;
    dms.enable = lib.mkDefault true;
    greeter = {
      configHome = lib.mkDefault "/home/${mainUser}";
      # Boot into the session behind the shell lock screen (DMS here) —
      # no greeter→session VT flash (see modules/features/desktop-hyprland.nix).
      autoLogin = lib.mkDefault true;
    };
  };
  features.fonts.enable = lib.mkDefault true;
}
