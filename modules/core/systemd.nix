{ lib, ... }:

{
  systemd = {
    settings.Manager = {
      DefaultTimeoutStopSec = lib.mkDefault "30s";
      DefaultTimeoutStartSec = lib.mkDefault "90s";
    };
    coredump.enable = false;
  };

  documentation.enable = false;
}
