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

  # Fleet journald policy: cap the journal on every host so a new host
  # can't inherit the upstream unbounded default. mkDefault — hosts
  # override wholesale (latitude "SystemMaxUse=100M"; nix-media's full
  # persistent block).
  services.journald.extraConfig = lib.mkDefault "SystemMaxUse=200M";

  # Default-off so a host can opt back in; no host does today.
  documentation.enable = lib.mkDefault false;
}
