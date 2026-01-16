{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.91.0.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NEW: SOPS-Nix for secret management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      lix-module,
      home-manager,
      lanzaboote,
      sops-nix, # Added to args
      ...
    }@inputs:
    let
      mkHost = import ./lib/mkHost.nix {
        inherit
          inputs
          nixpkgs
          self
          ;
        palette = import ./lib/palette.nix;
        overlays = import ./overlays { inherit inputs; };
      };
    in
    {
      nixosConfigurations = {
        yoga = mkHost {
          hostname = "yoga";
          mainUser = "david";
          profiles = [ "laptop" ];
          hmModules = [ ./hosts/yoga/home.nix ];
        };

        latitude = mkHost {
          hostname = "latitude";
          mainUser = "david";
          profiles = [
            "laptop"
            "desktop-gnome"
          ];
          hmModules = [ ./hosts/latitude/home.nix ];
        };
      };
    };
}
