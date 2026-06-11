{
  nixpkgs,
  inputs,
  self,
  colloidFluentOverlays ? [ ],
}:
{
  hostname,
  mainUser,
  system ? "x86_64-linux",
  profiles ? [ ],
  withHardware ? false, # Explicit toggle replacing 'needsHardware' heuristic
  useLixSource ? true,
  extraModules ? [ ],
  hmModules ? [ ],
  extraSpecialArgs ? { },
}:
let
  flakeRoot = self.outPath;
  profileModules = map (p: flakeRoot + "/profiles/${p}.nix") profiles;

  baseModules = [
    (flakeRoot + "/modules/core")
    (flakeRoot + "/modules/features")
  ]
  ++ nixpkgs.lib.optional withHardware (flakeRoot + "/modules/hardware");

  commonArgs = {
    inherit
      inputs
      self
      flakeRoot
      mainUser
      ;
    # Rationale: Utilize flake evaluation caching to avoid O(N) nixpkgs re-imports.
    # Note: Consuming modules should set `config.allowUnfree = true` if non-free pkgs are needed.
    homeDirectory = "/home/${mainUser}";
  }
  // extraSpecialArgs;
in
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = commonArgs;

  modules = [
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    inputs.disko.nixosModules.disko
    {
      nixpkgs = {
        config.allowUnfree = true;
        overlays = colloidFluentOverlays;
      };
      networking.hostName = hostname;

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = commonArgs;
        users.${mainUser}.imports = hmModules;
      };
    }
  ]
  ++ nixpkgs.lib.optional useLixSource inputs.lix-module.nixosModules.default
  ++ baseModules
  ++ profileModules
  ++ extraModules;
}
