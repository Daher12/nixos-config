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
  withHardware ? false, # opt in to modules/hardware (GPU/firmware etc.)
  lix ? true, # true → Lix from nixpkgs (cached), false → CppNix
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
    (flakeRoot + "/modules/roles")
  ]
  ++ nixpkgs.lib.optional withHardware (flakeRoot + "/modules/hardware")
  # Physical-machine optimizations (fwupd, firmware) — every current host is
  # bare metal; a future VM host would pass withHardware = false.
  ++ nixpkgs.lib.optional withHardware {
    hardware.isPhysical = nixpkgs.lib.mkDefault true;
  };

  commonArgs = {
    inherit
      inputs
      self
      flakeRoot
      mainUser
      ;
    # Rationale: Utilize flake evaluation caching to avoid O(N) nixpkgs re-imports.
    # allowUnfree is enabled unconditionally for every host in the modules block below.
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
      # Traceability: `nixos-version --configuration-revision` answers "which
      # commit is running". dirtyRev covers uncommitted working trees.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = commonArgs;
        users.${mainUser}.imports = hmModules;
      };
    }
  ]
  ++ nixpkgs.lib.optional lix (
    { pkgs, ... }: {
      nix.package = pkgs.lixPackageSets.latest.lix;
    }
  )
  ++ baseModules
  ++ profileModules
  ++ extraModules;
}
