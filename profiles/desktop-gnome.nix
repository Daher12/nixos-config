{
  lib,
  ...
}:

{
  features.desktop-gnome.enable = lib.mkDefault true;
  # autoLogin/autoLoginUser not set: both are the option defaults
  # (false / mainUser); hosts that want autologin set them explicitly.
  features.fonts.enable = lib.mkDefault true;
}
