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

  documentation.enable = lib.mkForce false;
}
