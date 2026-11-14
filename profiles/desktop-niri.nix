{ lib, ... }:

{
  # Daily-drive attr: boot lands straight in the niri session behind the
  # Noctalia lock screen (greeter.autoLogin); noctalia-greeter stays on for
  # the post-logout login screen.
  features = {
    desktop-niri = {
      enable = lib.mkDefault true;
      greeter.autoLogin = lib.mkDefault true;
    };
    fonts.enable = lib.mkDefault true;
  };
}
