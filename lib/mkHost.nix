# lib/mkHost.nix
{
  nixpkgs,
  inputs,
  self,
  palette,
  overlays,
}:

{
  hostname,
  mainUser,
  system ? "x86_64-linux",
  profiles ? [ "laptop" ],
  extraModules ? [ ],
  hmModules ? [ ],
  extraSpecialArgs ? { },
}:
let
  mkPkgs = import nixpkgs {
    inherit system;
    overlays = overlays.default;
    config.allowUnfree = true;
  };

  profileModules = map (p: "${self}/profiles/${p}.nix") profiles;

  baseModules = [
    "${self}/modules/core"
    "${self}/modules/hardware"
    "${self}/modules/features"
  ];
in
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = {
    inherit
      inputs
      self
      palette
      mainUser
      ;
  }
  // extraSpecialArgs;

  modules = [
    { nixpkgs.pkgs = mkPkgs; }
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
          inherit
            inputs
            self
            palette
            mainUser
            ;
        }
        // extraSpecialArgs;
        users.${mainUser}.imports = hmModules;
      };
    }
  ]
  ++ profileModules
  ++ baseModules
  ++ extraModules;
}
