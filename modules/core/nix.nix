{
  config,
  lib,
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

    optimise = {
      automatic = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatically optimize Nix store";
      };
      dates = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "weekly" ];
        description = "When to run Nix store optimisation";
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

        auto-optimise-store = false;
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
        http-connections = 64;
        connect-timeout = 5;
        download-attempts = 3;

        keep-derivations = false;
        keep-outputs = false;

        builders-use-substitutes = true;
        log-lines = lib.mkDefault 25;
        accept-flake-config = true;
        flake-registry = "";
      };

      registry = lib.mkDefault {
        nixpkgs.flake = inputs.nixpkgs;
        self.flake = self;
      };

      nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];

      gc = lib.mkIf cfg.gc.automatic {
        automatic = true;
        inherit (cfg.gc) dates;
        options = cfg.gc.flags;
      };

      optimise = lib.mkIf cfg.optimise.automatic {
        automatic = true;
        inherit (cfg.optimise) dates;
      };

      daemonCPUSchedPolicy = lib.mkDefault "idle";
      daemonIOSchedClass = lib.mkDefault "idle";
    };
  };
}
