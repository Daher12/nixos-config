{
  config,
  lib,
  ...
}:

let
  cfg = config.features.brave;
in
{
  options.features.brave = {
    enable = lib.mkEnableOption "managed Brave policies under /etc/brave/policies/managed";

    originMode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Flip BraveOriginFeatureEnabled — Brave Origin 'upgrade' mode, free on Linux since 1.91.";
    };

    extraPolicies = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra/override entries merged into the managed policy file.";
    };
  };

  # Origin feel = everything brave.com/origin lists as removed, disabled via
  # managed-policy names (verified against the deployed brave ELF 2026-10-04;
  # the six *Disabled/Enabled names + TorDisabled already proven live by the
  # former hand-maintained /etc/brave/policies/managed/bloat.json). Origin
  # mode itself should remove these too — the explicit list keeps the
  # stripped behavior even if Origin mode needs an entitlement this build
  # doesn't honor. Shields, De-Amp and search engine are deliberately untouched.
  config = lib.mkIf cfg.enable {
    environment.etc."brave/policies/managed/origin.json".text = builtins.toJSON (
      {
        BraveOriginFeatureEnabled = cfg.originMode;
        # Never grab the default browser (backup for --no-default-browser-check)
        DefaultBrowserSettingEnabled = false;
        # No background process after last window closes, no crash/usage upload
        BackgroundModeEnabled = false;
        MetricsReportingEnabled = false;
        # --- formerly in hand-maintained bloat.json (user-proven) ---
        BraveRewardsDisabled = true;
        BraveWalletDisabled = true;
        BraveVPNDisabled = true;
        BraveNewsDisabled = true;
        BraveTalkDisabled = true;
        TorDisabled = true;
        BraveAIChatEnabled = false;
        SyncDisabled = true;
        DnsOverHttpsMode = "automatic";
        # --- additional Origin removals ---
        BravePlaylistEnabled = false;
        BraveSpeedreaderEnabled = false;
        BraveWaybackMachineEnabled = false;
        BraveWebDiscoveryEnabled = false;
        # P3A "privacy-preserving analytics" + daily usage ping (Origin removes both)
        BraveP3AEnabled = false;
        BraveStatsPingEnabled = false;
      }
      // cfg.extraPolicies
    );
  };
}
