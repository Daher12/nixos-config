{ config, lib, ... }:

let
  cfg = config.features.oomd;
in
{
  options.features.oomd = {
    enable = lib.mkEnableOption "systemd-oomd memory pressure handling";
  };

  config = lib.mkIf cfg.enable {
    systemd.oomd = {
      enable = true;
      enableRootSlice = true;
      enableUserSlices = true;
      enableSystemSlice = true;
    };

    # NixOS' oomd defaults are pressure-only at a very lax 80% PSI and set no
    # swap-based rule. On zram-only hosts the kernel OOM killer can lag once the
    # swap device is full, so kill the biggest swap consumer when system swap
    # (zram + any disk fallback) is nearly exhausted. Fedora ships the same
    # swap-kill rules on -, system and user slices.
    systemd.slices = {
      "-".sliceConfig.ManagedOOMSwap = "kill";
      "system".sliceConfig.ManagedOOMSwap = "kill";
      "user".sliceConfig = {
        ManagedOOMSwap = "kill";
        # Tighten the pressure trigger on user sessions (nixpkgs default is 80%):
        # kill after 50% memory pressure sustained 20s, matching Fedora.
        ManagedOOMMemoryPressureLimit = "50%";
        ManagedOOMMemoryPressureDurationSec = "20s";
      };
    };

    # Prevent conflict with earlyoom
    services.earlyoom.enable = lib.mkForce false;
  };
}
