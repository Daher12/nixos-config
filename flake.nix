{
  description = "Unified NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    preload-ng = {
      url = "github:miguel-b-p/preload-ng";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode.url = "github:anomalyco/opencode";
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      # Kept locally only to satisfy formatter and check derivations
      system = "x86_64-linux";

      # Overlays shared between the local pkgs (for formatter/checks) and NixOS modules
      colloidFluentOverlays = [
        (final: _prev: {
          colloid-gtk-theme = final.callPackage ./pkgs/colloid-gtk-theme.nix { };
          fluent-icon-theme = final.callPackage ./pkgs/fluent-icon-theme.nix { };
          zcode = final.callPackage ./pkgs/zcode.nix { };
          mikromcp = final.callPackage ./pkgs/mikromcp.nix { };
        })
      ];

      # Rationale: Defer architecture binding to per-host evaluation. Avoids breaking non-x86 builds.
      mkHost = import ./lib/mkHost.nix {
        inherit
          nixpkgs
          inputs
          self
          colloidFluentOverlays
          ;
      };

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = colloidFluentOverlays;
      };
    in
    {
      formatter.${system} = pkgs.nixfmt;

      # CI/Lint Checks
      checks.${system} = {
        statix = pkgs.runCommand "statix-check" {
          buildInputs = [ pkgs.statix ];
        } "statix check ${self} && touch $out";

        deadnix = pkgs.runCommand "deadnix-check" {
          buildInputs = [ pkgs.deadnix ];
        } "deadnix --fail ${self} && touch $out";

        nixfmt = pkgs.runCommand "nixfmt-check" {
          buildInputs = [ pkgs.nixfmt ];
        } "find ${self} -name '*.nix' -exec nixfmt --check {} + && touch $out";
      };

      # VM tests — run explicitly, not part of `checks` (CI stays fast):
      # nix build .#nixosTests.x86_64-linux.litellm-gateway / .ssh-firewall
      nixosTests.${system} = pkgs.callPackage ./tests/litellm-firewall.nix {
        litellmModule = ./modules/features/litellm.nix;
      };

      # Secrets/ops toolshell (SOPS_RUNBOOK.md): `nix develop` puts sops, yq,
      # age, ssh-to-age and jq on PATH — no per-command `nix shell nixpkgs#…`
      # wrappers needed.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          sops
          age
          ssh-to-age
          yq-go
          jq
        ];
      };

      nixosConfigurations = {
        # Physical Laptop: Yoga (AMD)
        yoga = mkHost {
          hostname = "yoga";
          mainUser = "dk";
          withHardware = true; # Enables /modules/hardware evaluation
          profiles = [
            "laptop"
            "desktop-gnome"
          ];
          extraModules = [
            inputs.nixos-hardware.nixosModules.lenovo-yoga-7-slim-gen8
            ./hosts/yoga/default.nix
          ];
          hmModules = [ ./hosts/yoga/home.nix ];
          extraSpecialArgs = { };
        };

        # Physical Laptop: Latitude (Intel)
        latitude = mkHost {
          hostname = "latitude";
          mainUser = "dk";
          withHardware = true;
          lix = true;
          profiles = [
            "laptop"
            "desktop-gnome"
          ];
          extraModules = [
            inputs.preload-ng.nixosModules.default
            ./hosts/latitude/default.nix
          ];
          hmModules = [ ./hosts/latitude/home.nix ];
          extraSpecialArgs = { };
        };

        # Physical Media Server (Intel)
        nix-media = mkHost {
          hostname = "nix-media";
          mainUser = "dk";
          withHardware = true; # Enabled to support the physical Intel GPU for transcoding
          lix = false; # CppNix — headless server has no interactive use case for Lix improvements
          profiles = [ ];
          extraModules = [
            ./hosts/nix-media/default.nix
          ];
          hmModules = [ ./hosts/nix-media/home.nix ];
          extraSpecialArgs = { };
        };
      };
    };
}
