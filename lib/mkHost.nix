{ nixpkgs, inputs, self, palette, overlays }:
{ hostname, mainUser, system ? "x86_64-linux", profiles ? [], extraModules ? [], hmModules ? [], extraSpecialArgs ? {} }:
let
  profileModules = map (p: "${self}/profiles/${p}.nix") profiles;
  baseModules = [ "${self}/modules/core" "${self}/modules/hardware" "${self}/modules/features" ];
in
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit inputs self palette mainUser; } // extraSpecialArgs;
  modules = [
    inputs.lix-module.nixosModules.default
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.home-manager.nixosModules.home-manager
    {
      # CRITICAL: Configure pkgs via module system, DO NOT pass 'pkgs' arg to nixosSystem
      nixpkgs.overlays = overlays.default;
      nixpkgs.config.allowUnfree = true;
      
      networking.hostName = hostname;
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = { inherit inputs self palette mainUser; } // extraSpecialArgs;
        users.${mainUser}.imports = hmModules;
      };
    }
  ] ++ profileModules ++ baseModules ++ extraModules;
}
