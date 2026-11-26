{ config, lib, ... }:

{
  # rtkit is only meaningful for the pipewire/wireplumber clients; tying the
  # default to pipewire.enable keeps headless hosts (nix-media) from pulling
  # the rtkit setuid wrapper for nothing (audit 2026-11-26).
  security.rtkit.enable = lib.mkDefault config.services.pipewire.enable;

  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    jack.enable = lib.mkDefault true;
    extraConfig.pipewire."10-clock-rate" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 512;
        "default.clock.max-quantum" = 2048;
      };
    };
  };
}
