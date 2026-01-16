{ lib, mainUser, ... }:

{
  features.desktop-gnome = {
    enable = lib.mkDefault true;
    autoLogin = lib.mkDefault false;
    autoLoginUser = lib.mkDefault mainUser;
  };
  features.fonts.enable = lib.mkDefault true;
}
