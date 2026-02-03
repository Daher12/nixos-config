{
  nixpkgs,
  inputs,
  self,
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
  flakeRoot =
    if builtins.isAttrs self && self ? outPath then
      self.outPath
    else if builtins.isPath self then
      self
    else
      throw "mkHost: 'self' must be a flake object or a path.";

  profileModules = map (p: flakeRoot + "/profiles/${p}.nix") profiles;

  needsHardware = builtins.any (p: p == "laptop" || p == "desktop-gnome") profiles;
  needsFeatures = profiles != [ ];

  baseModules = [
    (flakeRoot + "/modules/core")
  ]
  ++ nixpkgs.lib.optional needsHardware (flakeRoot + "/modules/hardware")
  ++ nixpkgs.lib.optional needsFeatures (flakeRoot + "/modules/features");

  commonArgs = {
    inherit
      inputs
      self
      flakeRoot
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
    inputs.sops-nix.nixosModules.sops
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
