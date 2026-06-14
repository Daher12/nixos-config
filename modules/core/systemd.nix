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
    coredump.enable = false;
  };

  documentation.enable = false;
}
