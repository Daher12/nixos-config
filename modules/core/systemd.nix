{ lib, ... }:

{
  systemd = {
    settings.Manager = {
      DefaultTimeoutStopSec = lib.mkDefault "30s";
      DefaultTimeoutStartSec = lib.mkDefault "90s";
    };
    user.extraConfig = ''
      DefaultTimeoutStopSec=10s
    '';
    # Force-disable: no core dumps on desktop/laptop, no docs rebuild overhead
    coredump.enable = lib.mkForce false;
  };

  # Default-off so a host can opt back in; no host does today.
  documentation.enable = lib.mkDefault false;
}
