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
  # Defensive normalization: Ensure 'self' is a Path or Flake Object.
  # Rejects strings to prevent "context-less" import errors.
  flakeRoot =
    if builtins.isAttrs self && self ? outPath then self.outPath
    else if builtins.isPath self then self
    else throw "mkHost: 'self' must be a flake object or a path, got: ${builtins.typeOf self}";

  # Use flakeRoot for robust path concatenation.
  # This guarantees a valid Store Path and fails fast via native import error if missing.
  profileModules = map (p: flakeRoot + "/profiles/${p}.nix") profiles;

  # Conditional loading based on profile requirements
  needsHardware = builtins.any (p: p == "laptop" || p == "desktop-gnome") profiles;
  needsFeatures = profiles != [ ];

  # CONSISTENCY FIX: Use flakeRoot for all internal module paths.
  # This avoids mixed types (Path vs String) in the module list.
  baseModules = [
    (flakeRoot + "/modules/core")
  ]
  ++ nixpkgs.lib.optional needsHardware (flakeRoot + "/modules/hardware")
  ++ nixpkgs.lib.optional needsFeatures (flakeRoot + "/modules/features");

  # Pass inputs and self to modules (required for registry pinning)
  commonArgs = {
    inherit
      inputs
      self
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
