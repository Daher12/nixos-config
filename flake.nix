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
    
    preload-ng = {
      url = "github:miguel-b-p/preload-ng";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      
      overlays = import ./overlays/default.nix { inherit inputs; };
      
      mkPkgs = system: import nixpkgs {
        inherit system;
        overlays = overlays.default;
        config.allowUnfree = true;
      };

      mkHost = { hostname, modules, hmModules ? [], extraSpecialArgs ? {} }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; } // extraSpecialArgs;
          
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
                extraSpecialArgs = { inherit inputs; } // extraSpecialArgs;
                users.dk.imports = hmModules;
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
          modules = [
            inputs.preload-ng.nixosModules.default
            ./hosts/latitude/default.nix
          ];
          hmModules = [ ./hosts/latitude/home.nix ];
        };
      };
    };
}
