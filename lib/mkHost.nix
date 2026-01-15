{ nixpkgs, inputs, self, palette, overlays }:
{ hostname, mainUser, system ? "x86_64-linux", profiles ? [], extraModules ? [], hmModules ? [], extraSpecialArgs ? {} }:
let
  profileModules = map (p: "${self}/profiles/${p}.nix") profiles;
  baseModules = [ "${self}/modules/core" "${self}/modules/hardware" "${self}/modules/features" ];
  
  commonArgs = { inherit inputs self palette mainUser; } // extraSpecialArgs;
in
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = commonArgs;
  modules = [
    inputs.lix-module.nixosModules.default
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.home-manager.nixosModules.home-manager
    {
      nixpkgs.overlays = overlays.default;
      nixpkgs.config.allowUnfree = true;
      
      networking.hostName = hostname;
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = commonArgs;
        users.${mainUser}.imports = hmModules;
      };
    }
  ] ++ baseModules ++ profileModules ++ extraModules;
}
