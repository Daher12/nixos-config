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
      flakeRoot
      mainUser
      ;
    # Fleet SSH public keys (lib/keys.nix) — single source for the
    # authorizedKeys literals hosts declare.
    fleetKeys = import (flakeRoot + "/lib/keys.nix");
    homeDirectory = "/home/${mainUser}";
  };
in
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = commonArgs;

  modules = [
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    inputs.disko.nixosModules.disko
    {
      # Overlays go through nixpkgs.overlays (never nixpkgs.pkgs or a second
      # `import nixpkgs`), so each host has exactly one nixpkgs
      # instantiation. allowUnfree matches the flake-level pkgs in flake.nix.
      nixpkgs = {
        config.allowUnfree = true;
        overlays = colloidFluentOverlays;
      };
      networking.hostName = hostname;
      # Flake-only fleet: no channels. The flake registry and the NIX_PATH
      # nixpkgs pin come from nixpkgs' own wiring on every flake-built
      # system (nixos/modules/misc/nixpkgs-flake.nix); leftover /root
      # channel dirs after a switch only produce a non-fatal activation
      # warning (audit 2026-11-26).
      nix.channel.enable = false;
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
