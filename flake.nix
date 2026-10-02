{
  description = "Unified NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    preload-ng = {
      url = "github:miguel-b-p/preload-ng";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode.url = "github:anomalyco/opencode";

    # Quickshell engine — upstream flake (docs: the GitHub mirror is
    # equivalent to git.outfoxxed.me). follows is upstream-mandated
    # ("mismatched system dependencies will lead to crashes") and keeps
    # ONE nixpkgs eval in this flake. Manual pin like lucid/dank-greeter:
    # bump deliberately with `nix flake update quickshell`, then smoke-test
    # shell AND greeter (lucid v1.10.5 + DankGreeter 1.6.2 tested against
    # 0.3.1 — floor enforced in home/lucid.nix). No binary cache upstream:
    # first build per pin bump compiles locally.
    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # DankGreeter NixOS module (programs.dms-greeter) from upstream — newer
    # standalone greeter (1.6.2). Both module and package come from this
    # flake now, built against the main nixpkgs (follows; pure Go build).
    # Since 2026-09-30 the nixpkgs-unstable input is GONE — quickshell and
    # dms-greeter no longer ride it, so there is exactly one nixpkgs eval
    # in this flake and no binary cache for the desktop stack.
    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Lucid desktop shell (github:Sn3akyy1/lucid): Material 3 Expressive
    # Quickshell shell (bar, dock, launcher, lock screen, notifications,
    # settings GUI). Upstream ships no Nix packaging — the only install path
    # is an Arch install.sh — so the input is consumed as plain source
    # (flake = false): home/lucid.nix applies the downstream patches at BUILD
    # time (lucidPatched derivation over ./home/lucid-patches/, drift fails
    # the rebuild loudly) and syncs the result into the writable
    # ~/.config/quickshell (Lucid keeps runtime settings inside its own shell
    # directory, so a read-only store path cannot work). Deliberately NOT in
    # the update-safe/CI bump lists (moves fast, manual pin) — update with
    # `nix flake update lucid`, then regenerate the patches.
    lucid = {
      url = "github:Sn3akyy1/lucid";
      flake = false;
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      # Kept locally only to satisfy formatter and check derivations
      system = "x86_64-linux";

      # Overlays shared between the local pkgs (for formatter/checks) and NixOS modules
      colloidFluentOverlays = [
        (final: _prev: {
          colloid-gtk-theme = final.callPackage ./pkgs/colloid-gtk-theme.nix { };
          fluent-icon-theme = final.callPackage ./pkgs/fluent-icon-theme.nix { };
          zcode = final.callPackage ./pkgs/zcode.nix { };
          mikromcp = final.callPackage ./pkgs/mikromcp.nix { };
        })
        # Desktop stack from upstream flakes, built against the main nixpkgs
        # (quickshell's docs mark the follows "THIS IS IMPORTANT" — mismatched
        # system deps crash). nixpkgs-unstable is GONE: no second nixpkgs
        # eval, and no binary cache — the first build per pin bump compiles
        # quickshell locally. Greeter (AvengeMedia 1.6.2) runs at every boot;
        # Lucid (home/lucid.nix) runs on quickshell; both exec the SYSTEM
        # quickshell — any bump of quickshell/lucid/greeter is a three-way
        # pairing, see the floor gate in home/lucid.nix. The DMS shell itself
        # was removed 2026-09-27 (rollback: rebuild dms-caelestia-look@4b2f965
        # from history).
        (final: _prev: {
          dms-greeter = inputs.dank-greeter.packages.${final.stdenv.hostPlatform.system}.dms-greeter;
          quickshell = inputs.quickshell.packages.${final.stdenv.hostPlatform.system}.quickshell;
        })
      ];

      # Rationale: Defer architecture binding to per-host evaluation. Avoids breaking non-x86 builds.
      mkHost = import ./lib/mkHost.nix {
        inherit
          nixpkgs
          inputs
          self
          colloidFluentOverlays
          ;
      };

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = colloidFluentOverlays;
      };
    in
    {
      formatter.${system} = pkgs.nixfmt;

      # CI/Lint Checks
      checks.${system} = {
        statix = pkgs.runCommand "statix-check" {
          buildInputs = [ pkgs.statix ];
        } "statix check ${self} && touch $out";

        deadnix = pkgs.runCommand "deadnix-check" {
          buildInputs = [ pkgs.deadnix ];
        } "deadnix --fail ${self} && touch $out";

        nixfmt = pkgs.runCommand "nixfmt-check" {
          buildInputs = [ pkgs.nixfmt ];
        } "find ${self} -name '*.nix' -exec nixfmt --check {} + && touch $out";
      };

      # VM tests — run explicitly, not part of `checks` (CI stays fast):
      # nix build .#nixosTests.x86_64-linux.litellm-gateway / .ssh-firewall
      nixosTests.${system} = pkgs.callPackage ./tests/litellm-firewall.nix {
        litellmModule = ./modules/features/litellm.nix;
      };

      # Secrets/ops toolshell (SOPS_RUNBOOK.md): `nix develop` puts sops, yq,
      # age, ssh-to-age and jq on PATH — no per-command `nix shell nixpkgs#…`
      # wrappers needed.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          sops
          age
          ssh-to-age
          yq-go
          jq
        ];
      };

      nixosConfigurations = {
        # Physical Laptop: Yoga (AMD) — Hyprland + Lucid + DankGreeter.
        # Desktop switch (no config edits): rebuild from .#yoga-gnome for GNOME.
        yoga = mkHost {
          hostname = "yoga";
          mainUser = "dk";
          withHardware = true; # Enables /modules/hardware evaluation
          profiles = [
            "laptop"
            "desktop-hyprland"
          ];
          extraModules = [
            inputs.nixos-hardware.nixosModules.lenovo-yoga-7-slim-gen8
            ./hosts/yoga/default.nix
          ];
          hmModules = [ ./hosts/yoga/home.nix ];
          extraSpecialArgs = { };
        };

        # Same machine, GNOME desktop (GDM). Switch targets, nothing else differs.
        yoga-gnome = mkHost {
          hostname = "yoga";
          mainUser = "dk";
          withHardware = true;
          profiles = [
            "laptop"
            "desktop-gnome"
          ];
          extraModules = [
            inputs.nixos-hardware.nixosModules.lenovo-yoga-7-slim-gen8
            ./hosts/yoga/default.nix
          ];
          hmModules = [ ./hosts/yoga/home.nix ];
          extraSpecialArgs = { };
        };

        # Physical Laptop: Latitude (Intel)
        latitude = mkHost {
          hostname = "latitude";
          mainUser = "dk";
          withHardware = true;
          lix = true;
          profiles = [
            "laptop"
            "desktop-gnome"
          ];
          extraModules = [
            inputs.preload-ng.nixosModules.default
            ./hosts/latitude/default.nix
          ];
          hmModules = [ ./hosts/latitude/home.nix ];
          extraSpecialArgs = { };
        };

        # Physical Media Server (Intel)
        nix-media = mkHost {
          hostname = "nix-media";
          mainUser = "dk";
          withHardware = true; # Enabled to support the physical Intel GPU for transcoding
          lix = false; # CppNix — headless server has no interactive use case for Lix improvements
          profiles = [ ];
          extraModules = [
            ./hosts/nix-media/default.nix
          ];
          hmModules = [ ./hosts/nix-media/home.nix ];
          extraSpecialArgs = { };
        };
      };
    };
}
