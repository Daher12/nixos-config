{
  config,
  lib,
  pkgs,
  inputs,
  self,
  mainUser,
  ...
}:

let
  cfg = config.core.nix;
in
{
  options.core.nix = {
    gc = {
      automatic = lib.mkEnableOption "automatic garbage collection";
      dates = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "When to run garbage collection";
      };

      options = lib.mkOption {
        type = lib.types.str;
        default = "--delete-older-than 30d";
        description = "Options passed to nix-collect-garbage";
      };
    };
    optimise = {
      automatic = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatically optimize Nix store";
      };
    };
  };

  config = {
    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        
        # FIX: Use mkDefault for settings that might vary by host hardware
        auto-optimise-store = lib.mkDefault true;
        max-jobs = lib.mkDefault "auto";
        cores = lib.mkDefault 0;
        
        trusted-users = [
          "root"
          mainUser
        ];
        
        sandbox = lib.mkDefault true;
        sandbox-fallback = false;

        min-free = 5368709120;
        max-free = 21474836480;
        
        substituters = [
          "https://cache.nixos.org"
          "https://cache.lix.systems"
          "https://nix-community.cachix.org"
        ];
        
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
        ];
        
        fallback = lib.mkDefault true;
        http-connections = 128;
        connect-timeout = 5;
        download-attempts = 3;
        stalled-download-timeout = 300;

        keep-derivations = false;
        keep-outputs = false;

        builders-use-substitutes = true;
        log-lines = lib.mkDefault 25;
        accept-flake-config = true;
        narinfo-cache-negative-ttl = 3600;
        narinfo-cache-positive-ttl = 2592000;
        
        # Purity: Disable the global registry to prevent 'surprise' network lookups.
        # We rely solely on the pinned registry entries below.
        flake-registry = "";
      };

      # Pin only essential flakes to the registry.
      # This ensures 'nix shell nixpkgs#foo' uses the EXACT version from flake.lock.
      registry = lib.mkDefault {
        nixpkgs.flake = inputs.nixpkgs;
        self.flake = self;
      };

      # Add pinned nixpkgs to NIX_PATH for legacy tools (nix-shell).
      # .outPath ensures we get the store path safely.
      nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];

      gc = lib.mkIf cfg.gc.automatic {
        automatic = true;
        inherit (cfg.gc) dates options;
      };
      optimise = lib.mkIf cfg.optimise.automatic {
        automatic = true;
        dates = [ "weekly" ];
      };
    };

    systemd.services.nix-daemon.serviceConfig = {
      # FIX: Use mkDefault so high-performance build servers can override these limits
      Slice = "background.slice";
      Nice = lib.mkDefault 10;
      CPUWeight = lib.mkDefault 50;
      IOWeight = lib.mkDefault 50;
      IOSchedulingClass = lib.mkDefault "best-effort";
      MemoryHigh = lib.mkDefault "80%";
      LimitNOFILE = 1048576;
    };

    systemd.services.NetworkManager-wait-online.wantedBy = lib.mkForce [ ];
    environment.systemPackages = [ pkgs.cachix ];
  };
}
