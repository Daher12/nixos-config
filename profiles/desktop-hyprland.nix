{
  lib,
  mainUser,
  ...
}:

{
  features.desktop-hyprland = {
    enable = lib.mkDefault true;
    withUWSM = lib.mkDefault true;
    greeter.configHome = lib.mkDefault "/home/${mainUser}";
  };
  features.fonts.enable = lib.mkDefault true;
}
