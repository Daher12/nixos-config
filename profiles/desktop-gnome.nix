{ lib, mainUser, ... }:

{
  features.desktop-gnome = {
    enable = lib.mkDefault true;
    autoLogin = lib.mkDefault false;
    autoLoginUser = lib.mkDefault mainUser;
  };

  # Removed: Tailscale (moved to laptop.nix / per-host)
  # Removed: System76 Scheduler (moved to laptop.nix)
}
