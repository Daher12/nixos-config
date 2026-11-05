{
  lib,
  mainUser,
  ...
}:

{
  features.desktop-niri = {
    enable = lib.mkDefault true;
    # DankGreeter stays for the login screen (running on the niri
    # compositor); no autoLogin on the trial attr — the greeter shows first
    # so the session choice is explicit.
    greeter.configHome = lib.mkDefault "/home/${mainUser}";
  };
  features.fonts.enable = lib.mkDefault true;
}
