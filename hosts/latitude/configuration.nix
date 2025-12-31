{ config, pkgs, lib, unstable, ... }:

{
  imports = [
    # --- Local Hardware Specifics ---
    ./hardware-configuration.nix
    # ./nvidia.nix  <-- Removed: Integrated directly below (Nvidia Killswitch)
    
    # --- The Common Base ---
    ../../modules/common.nix
    
    # --- Shared Modules ---
    ## ../../modules/console.nix
    ../../modules/fonts.nix
    ../../modules/virtualization.nix
    ../../modules/gnome.nix
  ];

  # ===========================================================================
  # SYSTEM IDENTITY
  # ===========================================================================
  system.stateVersion = "25.05";
  networking.hostName = "e7450-nixos";

  # ===========================================================================
  # KONSOLEN-FIXES (Manuell übernommen aus console.nix)
  # ===========================================================================
  
  # 1. Deutsches Layout auch in der Text-Konsole erzwingen
  console.useXkbConfig = true;

  # 2. "Silent Boot": Text-Login auf TTY1 unterdrücken (verhindert Flackern vor GDM)
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;


  # ===========================================================================
  # HARDWARE TUNING (Dell Latitude E7450 & Broadwell)
  # ===========================================================================
  
  # Kernel Selection
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Boot & Kernel Optimizations
  boot.kernelParams = [
    # Intel Graphics Power Saving
    "i915.enable_fbc=1"      # Framebuffer compression
    "i915.fastboot=1"        # Flicker-free boot
    
    # Power Management
    "pcie_aspm=force"        # Aggressive PCIe power saving
    "mem_sleep_default=deep" # Force S3 Deep Sleep (Critical for E7450)
    "zswap.enabled=0"        # Disable zswap (Using ZRAM from common.nix instead)
  ];

  # Scheduler (System76 - specific to this host)
  services.system76-scheduler = {
    enable = true;
    useStockConfig = true;
    settings.processScheduler.foregroundBoost.enable = true;
  };

  # Graphics (Intel Broadwell)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ 
      intel-media-driver 
      libvdpau-va-gl 
    ];
  };
  environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; };

  fileSystems."/" = {
    options = lib.mkAfter [ 
      "noatime"     # Do not update access times on reads (reduces writes)
      "nodiratime"  # Do not update directory access times
      "commit=30"   # Write metadata to disk every 30s (default is 5s)
    ];
  };
  
  services.preload-ng = {
    enable = true;
    settings = {
      # SSD Optimierung: Kein I/O Reordering nötig
      sortStrategy = 0; 
      
      # RAM Strategie für 16GB:
      # Nutze maximal 90% des Gesamtspeichers als Obergrenze
      memTotal = -10;
      # Nutze aggressiv 50% des gerade freien Speichers für Caching
      memFree = 50;
      
      # Standardwerte explizit setzen für Stabilität
      minSize = 2000000; # Erst ab 2MB Größe tracken
      cycle = 30;        # Alle 20s prüfen
    };
  };

  # ===========================================================================
  # NVIDIA KILLSWITCH (0W Power Draw Strategy)
  # ===========================================================================
  # Integrated from latitude.nix
  
  # 1. Blacklist Drivers
  boot.blacklistedKernelModules = [ 
    "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" 
  ];

  # 2. Kernel Options to prevent loading
  boot.extraModprobeConfig = ''
    blacklist nouveau
    options nouveau modeset=0
  '';

  # 3. Udev Rule: Physically remove device from PCI bus
  services.udev.extraRules = ''
    # Remove NVIDIA PCI devices (Vendor ID 0x10de)
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", \
      ATTR{class}=="0x0c0330|0x0c8000|0x040300|0x03*", \
      ATTR{power/control}="auto", ATTR{remove}="1"
  '';

  # ===========================================================================
  # POWER MANAGEMENT
  # ===========================================================================
  
  # Disable GNOME's default power profile daemon to allow TLP to work
  services.power-profiles-daemon.enable = false;
  services.thermald.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
      CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      
      # Critical for Suspend on E7450: Allow USB bus to power down
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_BTUSB = 0;
    };
  };

  # Custom Service: Fix Suspend Battery Drain (USB Wakeups)
  # Disables wakeups from USB (EHC1/XHC) to ensure deep sleep
  systemd.services.disable-wakeup-sources = {
    description = "Disable spurious wakeups from USB to save power";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "disable-wakeups" ''
        disable_wakeup() {
          if grep -q "^$1.*enabled" /proc/acpi/wakeup; then
            echo $1 > /proc/acpi/wakeup
          fi
        }
        disable_wakeup EHC1
        disable_wakeup XHC 
      '';
    };
  };

  # ===========================================================================
  # SYSTEM MAINTENANCE & PACKAGES
  # ===========================================================================
  
  # Latitude-specific packages
  environment.systemPackages = with pkgs; [
   libva-utils sbctl
  ];

  # Log Compression for Ext4 (Not present in common.nix)
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    Compress=yes
  '';

  # Note: Global sysctl tuning (BBR, Swappiness 100) and 
  # Systemd Timeouts are inherited from common.nix
}
