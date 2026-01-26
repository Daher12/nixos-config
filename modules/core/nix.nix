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

      flags = lib.mkOption {
        type = lib.types.str;
        default = "--delete-older-than 30d";
        description = "Options passed to nix-collect-garbage";
      };
    };
    
    optimise.automatic = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically optimize Nix store";
    };
  };

  config = {
    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];

        auto-optimise-store = lib.mkDefault true;
        max-jobs = lib.mkDefault "auto";
        cores = lib.mkDefault 0;

        trusted-users = [
          "root"
          mainUser
        ];

        sandbox = lib.mkDefault true;
        sandbox-fallback = false;

        min-free = 5368709120; # 5GB
        max-free = 21474836480; # 20GB

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

        flake-registry = "";
      };

      registry = lib.mkDefault {
        nixpkgs.flake = inputs.nixpkgs;
        self.flake = self;
      };

      nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];

      gc = lib.mkIf cfg.gc.automatic {
        automatic = true;
        # FIX: Use inherit to satisfy linter (assignment match)
        inherit (cfg.gc) dates;
        # Note: 'options' maps to 'flags', so it cannot be inherited.
        options = cfg.gc.flags;
      };
      
      optimise = lib.mkIf cfg.optimise.automatic {
        automatic = true;
        dates = [ "weekly" ];
      };
    };

    systemd.services.nix-daemon.serviceConfig = {
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
