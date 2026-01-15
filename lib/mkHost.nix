{ nixpkgs, inputs, self, palette, overlays }:
{ hostname, mainUser, system ? "x86_64-linux", profiles ? [], extraModules ? [], hmModules ? [], extraSpecialArgs ? {} }:
let
  profileModules = builtins.filter builtins.pathExists (map (p: "${self}/profiles/${p}.nix") profiles);
  
  # Conditional loading based on profile requirements
  needsHardware = builtins.any (p: p == "laptop" || p == "desktop-gnome") profiles;
  needsFeatures = profiles != [];
  
  baseModules = [ "${self}/modules/core" ]
    ++ nixpkgs.lib.optional needsHardware "${self}/modules/hardware"
    ++ nixpkgs.lib.optional needsFeatures "${self}/modules/features";
  
  # Simplified specialArgs - extraSpecialArgs already contains winappsPackages
  commonArgs = { 
    inherit inputs self palette mainUser;
  } // extraSpecialArgs;
in
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = commonArgs;
  modules = [
    inputs.lix-module.nixosModules.default
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.home-manager.nixosModules.home-manager
    {
      nixpkgs.overlays = overlays system;
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
