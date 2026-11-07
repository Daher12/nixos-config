{ lib, ... }:

{
  # noctalia-greeter stays on for the login screen; no autoLogin on the
  # trial attr — the greeter shows first so the session choice is explicit.
  features.desktop-niri.enable = lib.mkDefault true;
  features.fonts.enable = lib.mkDefault true;
}
