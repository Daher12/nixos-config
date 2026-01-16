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
  profiles ? [ ],
  extraModules ? [ ],
  hmModules ? [ ],
  extraSpecialArgs ? { },
}:
let
  # 1. Robust Normalization: Handle self as Flake Object OR Path.
  # This prevents errors if 'self' structure varies (e.g. in repl vs build).
  flakeRoot = 
    if builtins.isAttrs self && self ? outPath then self.outPath
    else if builtins.isPath self then self
    else throw "mkHost: 'self' must be a flake object or a path.";

  # 2. Use flakeRoot for robust path concatenation.
  profileModules = map (p: flakeRoot + "/profiles/${p}.nix") profiles;

  needsHardware = builtins.any (p: p == "laptop" || p == "desktop-gnome") profiles;
  needsFeatures = profiles != [ ];

  # 3. Consistency: Use flakeRoot for all internal paths
  baseModules = [
    (flakeRoot + "/modules/core")
  ]
  ++ nixpkgs.lib.optional needsHardware (flakeRoot + "/modules/hardware")
  ++ nixpkgs.lib.optional needsFeatures (flakeRoot + "/modules/features");

  commonArgs = {
    inherit
      inputs
      self       # Passed for Registry Pinning (Flake Object)
      flakeRoot  # Passed for File Access (Store Path)
      palette
      mainUser
      ;
  }
  // extraSpecialArgs;
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
  ]
  ++ baseModules
  ++ profileModules
  ++ extraModules;
}
