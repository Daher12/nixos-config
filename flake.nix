{
  description = "Unified NixOS Configuration (Yoga + Latitude)";

  inputs = {
    # --- Base ---
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # --- Hardware & Tools ---
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

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

    winapps = {
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # [NEU] Preload-NG Input
    preload-ng = {
      url = "github:miguel-b-p/preload-ng";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, lanzaboote, home-manager, winapps, lix-module, preload-ng, ... }:
    let
      system = "x86_64-linux";

      # 1. Overlays laden
      myOverlays = import ./overlays/default.nix { inherit inputs; };

      # 2. Pkgs einmalig instanziieren
      pkgs = import nixpkgs {
        inherit system;
        overlays = myOverlays.default;
        config = {
          allowUnfree = true;
          contentAddressedByDefault = false;
        };
      };
      
      # Shared Arguments
      # Reduziert auf Inputs, um Module zu entkoppeln.
      # - Zugriff auf Unstable erfolgt nun via pkgs.unstable (Overlay)
      # - Zugriff auf Palette erfolgt via import ./lib/palette.nix in den Modulen
      sharedArgs = {
        inherit inputs;
      };

    in
    {
      formatter.${system} = pkgs.nixfmt-rfc-style;

      nixosConfigurations = {
        
        # --- Host: Yoga (Ohne Preload-NG) ---
        yoga = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = sharedArgs;
          modules = [
            { nixpkgs.pkgs = pkgs; }

            lix-module.nixosModules.default
            lanzaboote.nixosModules.lanzaboote
            home-manager.nixosModules.home-manager
            inputs.nixos-hardware.nixosModules.lenovo-yoga-7-slim-gen8

            ./hosts/yoga/default.nix

            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                
                # Winapps explizit hier übergeben, da nur Yoga es nutzt
                extraSpecialArgs = sharedArgs // {
                  winappsPackages = inputs.winapps.packages.${system};
                };
                
                users.dk = import ./hosts/yoga/home.nix;
                verbose = false;
              };
            }
          ];
        };

        # --- Host: Latitude (Mit Preload-NG) ---
        "e7450-nixos" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = sharedArgs;
          modules = [
            { nixpkgs.pkgs = pkgs; }
            
            lix-module.nixosModules.default
            lanzaboote.nixosModules.lanzaboote
            home-manager.nixosModules.home-manager
            
            # [NEU] Modul nur hier laden
            inputs.preload-ng.nixosModules.default
             
            ./hosts/latitude/configuration.nix

            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                extraSpecialArgs = sharedArgs;
                users.dk = import ./hosts/latitude/home.nix;
                verbose = false;
              };
            }
          ];
        };
      };
    };
}
