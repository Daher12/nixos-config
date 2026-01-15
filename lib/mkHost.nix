{ nixpkgs, inputs, self, palette, overlays }:
{ hostname, mainUser, system ? "x86_64-linux", profiles ? [], extraModules ? [], hmModules ? [], extraSpecialArgs ? {} }:
let
  profileModules = builtins.filter builtins.pathExists (map (p: "${self}/profiles/${p}.nix") profiles);
  
  # Only load hardware/features modules when profiles exist
  baseModules = [ "${self}/modules/core" ]
    ++ nixpkgs.lib.optional (profiles != []) "${self}/modules/hardware"
    ++ nixpkgs.lib.optional (profiles != []) "${self}/modules/features";
  
  # Type-safe specialArgs with guaranteed winappsPackages key
  commonArgs = { 
    inherit inputs self palette mainUser;
    winappsPackages = extraSpecialArgs.winappsPackages or null;
  } // (builtins.removeAttrs extraSpecialArgs ["winappsPackages"]);
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
