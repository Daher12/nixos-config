{
  description = "Unified NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lix-module = {
      url = "git+https://git.lix.systems/lix-project/nixos-module?ref=release-2.93";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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

    impermanence.url = "github:nix-community/impermanence";
    winapps = {
      url = "github:winapps-org/winapps/44342c34b839547be0b2ea4f94ed00293fa7cc38";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    preload-ng = {
      url = "github:miguel-b-p/preload-ng/eb3c66a20d089ab2e3b8ff34c45c3d527584ed38";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      # Kept locally only to satisfy formatter and check derivations
      system = "x86_64-linux";

      # Rationale: Defer architecture binding to per-host evaluation. Avoids breaking non-x86 builds.
      mkHost = import ./lib/mkHost.nix {
        inherit
          nixpkgs
          inputs
          self
          ;
      };

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      formatter.${system} = pkgs.nixfmt-rfc-style;

      # CI/Lint Checks
      checks.${system} = {
        statix = pkgs.runCommand "statix-check" {
          buildInputs = [ pkgs.statix ];
        } "statix check ${self} && touch $out";
        deadnix = pkgs.runCommand "deadnix-check" {
          buildInputs = [ pkgs.deadnix ];
        } "deadnix --fail ${self} && touch $out";
        nixfmt = pkgs.runCommand "nixfmt-check" {
          buildInputs = [ pkgs.nixfmt-rfc-style ];
        } "find ${self} -name '*.nix' -exec nixfmt --check {} + && touch $out";
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
          extraSpecialArgs = {
            winappsPackages = inputs.winapps.packages.${system};
          };
        };

        # Physical Laptop: Latitude (Intel)
        latitude = mkHost {
          hostname = "latitude";
          mainUser = "dk";
          withHardware = true;
          profiles = [
            "laptop"
            "desktop-gnome"
          ];
          extraModules = [
            inputs.preload-ng.nixosModules.default
            ./hosts/latitude/default.nix
          ];
          hmModules = [ ./hosts/latitude/home.nix ];
          extraSpecialArgs = {
            winappsPackages = null;
          };
        };

        # Physical Media Server (Intel)
        nix-media = mkHost {
          hostname = "nix-media";
          mainUser = "dk";
          withHardware = true; # Enabled to support the physical Intel GPU for transcoding
          profiles = [ ];
          extraModules = [
            ./hosts/nix-media/default.nix
          ];
          hmModules = [ ./hosts/nix-media/home.nix ];
          extraSpecialArgs = {
            winappsPackages = null;
          };
        };
      };
    };
}
