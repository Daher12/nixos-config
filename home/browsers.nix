{ pkgs, ... }:
{
  # --- FIREFOX (Primary) ---
  programs.firefox = {
    enable = true;
    policies = {
      DisablePocket = true;
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      UserMessaging = {
        ExtensionRecommendations = false;
        SkipOnboarding = true;
      };
      # Enterprise Extension Management
      ExtensionSettings = {
        # uBlock Origin
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        # Bitwarden
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
        # Multi-Account Containers
        "@testpilot-containers" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
    profiles.dk = {
      isDefault = true;
      settings = {
        # RAM Cache > Disk Cache (Speed + SSD Longevity)
        "browser.cache.disk.enable" = false;
        "browser.cache.memory.enable" = true;
        "browser.cache.memory.capacity" = 524288; # 512MB
        "browser.shell.checkDefaultBrowser" = false;
        "browser.ctrlTab.sortByRecentlyUsed" = true;
      };
    };
  };

  # --- BRAVE (Secondary/Fallback) ---
  programs.brave = {
    enable = true;
    package = pkgs.brave;
    extensions = [
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
    ];
    commandLineArgs = [
      "--disk-cache-dir=/dev/shm/brave-cache" # Use RAM for cache
      "--disk-cache-size=536870912" 
    ];
  };
}
