{
  config,
  lib,
  mainUser,
  ...
}:

let
  cfg = config.core.nix;
in
{
  options.core.nix = {
    trustedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ mainUser ];
      description = "Users with root-equivalent nix access (trust settings, substituters). root is appended by NixOS itself; headless hosts may narrow this to [ ].";
    };

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

        # max-jobs/cores/sandbox/auto-optimise-store are not set: their values
        # here equaled the nixpkgs defaults (config/nix.nix, verified
        # 2026-11-26 audit). builders-use-substitutes is likewise gone — no
        # buildMachines are configured anywhere in the fleet.

        trusted-users = cfg.trustedUsers;

        sandbox-fallback = false;

        min-free = 5368709120;
        max-free = 21474836480;

        # cache.nixos.org and its key are appended by NixOS itself
        # (nixos/modules/config/nix.nix: substituters via mkAfter) — the old
        # plain definitions here made the generated nix.conf carry both twice.
        # mkForce keeps our order (official cache first) without the dupes.
        substituters = lib.mkForce [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          # Noctalia shell + greeter (flake inputs noctalia/noctalia-greeter,
          # yoga-niri): hits only because the inputs carry NO nixpkgs follows.
          "https://noctalia.cachix.org"
        ];

        trusted-public-keys = lib.mkForce [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        ];

        fallback = lib.mkDefault true;
        http-connections = lib.mkDefault 32;
        connect-timeout = 5;
        download-attempts = 3;

        keep-derivations = false;
        keep-outputs = false;

        log-lines = lib.mkDefault 25;
        accept-flake-config = false;
        flake-registry = "";
      };

      # The flake registry + NIX_PATH nixpkgs pin are not set here: NixOS
      # wires both itself on flake-built systems
      # (nixos/modules/misc/nixpkgs-flake.nix — registry.nixpkgs.to +
      # nixpkgs=flake:nixpkgs). The old registry/nixPath definitions only
      # re-declared that (the self entry never even survived the merge).

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
