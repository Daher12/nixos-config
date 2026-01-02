{
  description = "Unified NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Pinned to specific commits for reproducibility
    nixos-hardware.url = "github:NixOS/nixos-hardware/40b1a28dce561bea34858287fbb23052c3ee63fe";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.93.3-2.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned for reproducibility
    winapps = {
      url = "github:winapps-org/winapps/44342c34b839547be0b2ea4f94ed00293fa7cc38";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    preload-ng = {
      url = "github:miguel-b-p/preload-ng/eb3c66a20d089ab2e3b8ff34c45c3d527584ed38";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      system = "x86_64-linux";

      # Memoized unstable import - evaluated once, reused in overlay
      pkgs-unstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      # Shared palette for theming
      palette = import ./lib/palette.nix;

      overlays = import ./overlays/default.nix {
        inherit inputs pkgs-unstable;
      };

      mkPkgs = system: import nixpkgs {
        inherit system;
        overlays = overlays.default;
        config.allowUnfree = true;
      };

      # Host factory with unified specialArgs
      mkHost = {
        hostname,
        mainUser,
        modules,
        hmModules ? [],
        extraSpecialArgs ? {}
      }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs self palette mainUser;
          } // extraSpecialArgs;

          modules = [
            { nixpkgs.pkgs = mkPkgs system; }
            inputs.lix-module.nixosModules.default
            inputs.lanzaboote.nixosModules.lanzaboote
            inputs.home-manager.nixosModules.home-manager

            {
              networking.hostName = hostname;

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                extraSpecialArgs = {
                  inherit inputs self palette mainUser;
                } // extraSpecialArgs;
                users.${mainUser}.imports = hmModules;
                verbose = false;
              };
            }
          ] ++ modules;
        };
    in
    {
      formatter.${system} = (mkPkgs system).nixfmt-rfc-style;

      nixosConfigurations = {
        yoga = mkHost {
          hostname = "yoga";
          mainUser = "dk";
          modules = [
            inputs.nixos-hardware.nixosModules.lenovo-yoga-7-slim-gen8
            ./hosts/yoga/default.nix
          ];
          hmModules = [ ./hosts/yoga/home.nix ];
          extraSpecialArgs = {
            winappsPackages = inputs.winapps.packages.${system};
          };
        };

        e7450-nixos = mkHost {
          hostname = "e7450-nixos";
          mainUser = "dk";
          modules = [
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
