{
  description = "Unified NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.3";
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

    # [INTEGRATION] Added SOPS-Nix for secret management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
    inputs@{
      self,
      nixpkgs,
      sops-nix, # [INTEGRATION] Explicitly listed (available via inputs@ too)
      ...
    }:
    let
      system = "x86_64-linux";

      pkgs-unstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      palette = import ./lib/palette.nix;

      # [INTEGRATION] Refactored overlays to match mkHost expectation.
      # mkHost expects a function: system -> [ overlays ]
      overlays = _system: [
        (_: _: { unstable = pkgs-unstable; })
      ];

      mkHost = import ./lib/mkHost.nix {
        inherit
          nixpkgs
          inputs
          self
          palette
          overlays
          ;
      };

      # Only used for formatter/checks
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      formatter.${system} = pkgs.nixfmt-rfc-style;

      checks.${system} = {
        statix = pkgs.runCommand "statix-check" { buildInputs = [ pkgs.statix ]; } ''
          statix check ${self} && touch $out
        '';
        deadnix = pkgs.runCommand "deadnix-check" { buildInputs = [ pkgs.deadnix ]; } ''
          deadnix --fail ${self} && touch $out
        '';
        nixfmt = pkgs.runCommand "nixfmt-check" { buildInputs = [ pkgs.nixfmt-rfc-style ]; } ''
          find ${self} -name '*.nix' -exec nixfmt --check {} + && touch $out
        '';
      };

      nixosConfigurations = {
        yoga = mkHost {
          hostname = "yoga";
          mainUser = "dk"; # Updated from previous example to match your file
          profiles = [
            "laptop"
            "desktop-gnome" # [NOTE] Ensure you actually want gnome on the yoga
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

        "e7450-nixos" = mkHost {
          hostname = "latitude";
          mainUser = "dk";
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
      };
    };
}
