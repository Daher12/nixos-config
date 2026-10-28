{
  description = "Unified NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hard-pinned to the latest stable tag: lanzaboote owns Secure Boot key
    # enrollment (lanzaboote-tool runs on every boot), so it never moves via
    # the routine update sweep — only via the CI workflow_dispatch toggle
    # include_lanzaboote or an explicit request.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
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

    # Pinned to the v2 line: Obsidian Copilot >= 4.0.12 requires opencode
    # 2.0.3+, while the default branch still tracks 1.x. Flakes cannot
    # express "latest v2.*", so bump by editing the tag below, then
    # `nix flake update opencode`. Find the newest tag with:
    #   git ls-remote --tags https://github.com/anomalyco/opencode 'v2.*'
    # v2.0.28+ were UNBUILDABLE from the flake (their nix/node_modules.nix
    # src fileset didn't ship ../script for
    # packages/cli/script/build.ts's ../../../script/native-arch import).
    # Upstream fixed it in 3171839709 ("fix(nix): ship the root script/ dir
    # to the CLI build", 2026-10-19, first shipped in the v2.1 line) — the
    # pin resumed moving at v2.1.4 (2026-10-24 sweep) and reached v2.2.0 in
    # the 2026-10-28 sweep (gate: `nix build github:anomalyco/opencode/v2.2.0`
    # clean before touching this tag — keep that gate per bump).
    # Deliberately NO `nixpkgs.follows` here: upstream requires its pinned
    # nixpkgs-unstable (packageManager bun@1.4.2; nixos-26.05 only ships
    # bun 1.3.13, whose `bun install` fails extracting the big native
    # tarballs and hangs the build). Cost: the flake's only second nixpkgs
    # eval (input nixpkgs_2) — everything else shares the main one.
    # The libstdc++ LD_LIBRARY_PATH wrap in home/opencode.nix covers the
    # resulting stdenv mismatch.
    opencode = {
      url = "github:anomalyco/opencode/v2.2.0";
    };

    # Quickshell engine — upstream flake (docs: the GitHub mirror is
    # equivalent to git.outfoxxed.me). follows is upstream-mandated
    # ("mismatched system dependencies will lead to crashes") and keeps the
    # desktop stack on the single main nixpkgs eval. Manual pin like
    # lucid/dank-greeter: bump deliberately with `nix flake update
    # quickshell`, then smoke-test shell AND greeter (lucid v1.20.1 +
    # dux-greeter v2.0.0 — the pairing floor `minQuickshell = "0.3.2"` is
    # enforced in home/lucid.nix). No binary cache upstream: first build
    # per pin bump compiles locally.
    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # dux-greeter NixOS module (programs.dms-greeter) from upstream — newer
    # standalone greeter (v2.0.0 rebrand, 2026-10-20). Both module and
    # package come from this flake now, built against the main nixpkgs
    # (follows; pure Go build).
    # Repo was renamed AvengeMedia/dank-greeter → duxlabs-dev/dux-greeter
    # (URL updated 2026-10-24 while the GitHub redirect still works —
    # redirects can expire). Since 2026-09-30 the nixpkgs-unstable input is
    # GONE — quickshell and dms-greeter no longer ride it, so the desktop
    # stack has one nixpkgs eval (opencode's pinned input is the only
    # second one) and no binary cache.
    dank-greeter = {
      url = "github:duxlabs-dev/dux-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Spotify desktop client patched with SpotX (ad blocking) at build
    # time. Overlay-only upstream flake (no NixOS/HM module), consumed by
    # modules/features/spotify.nix. Manual pin like lucid/quickshell: the
    # upstream bot re-aligns SpotX-Bash with nixpkgs' spotify every ~6 h,
    # and we follow OUR nixpkgs — if a nixpkgs bump outpaces their pin,
    # the spotify-spotx build fails loudly ("Nixpkgs Spotify X is newer
    # than SpotX-Bash Y"). Fix: `nix flake update spotx-nix`. Deliberately
    # NOT in the update-safe list.
    spotx-nix = {
      url = "github:SpotX-Official/SpotX-Nix";
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
          is-on-ac = final.callPackage ./pkgs/is-on-ac.nix { };
        })
        # Desktop stack from upstream flakes, built against the main nixpkgs
        # (quickshell's docs mark the follows "THIS IS IMPORTANT" — mismatched
        # system deps crash). nixpkgs-unstable is GONE: the desktop stack
        # rides the main nixpkgs eval (opencode's pinned input is the only
        # second one), and there is no binary cache — the first build per pin
        # bump compiles quickshell locally. Greeter (duxlabs-dev 1.6.2) runs
        # at every boot; Lucid (home/lucid.nix) runs on quickshell; both exec
        # the SYSTEM quickshell — any bump of quickshell/lucid/greeter is a
        # three-way pairing, see the floor gate in home/lucid.nix.
        (final: _prev: {
          dms-greeter = inputs.dank-greeter.packages.${final.stdenv.hostPlatform.system}.dms-greeter;
          # withModules appends Qt modules to the wrapper derivation, whose
          # wrapQtAppsHook folds their qml dirs into the baked
          # NIXPKGS_QT6_QML_IMPORT_PATH (bin/qs is a makeQtWrapper C wrapper,
          # not a shell script — runtime env overrides cannot extend that
          # list safely). lucid v1.20 imports Qt5Compat.GraphicalEffects
          # (lucidbar/Workspaces.qml, lucidui/ShapedImage.qml; upstream docs
          # list qt6-5compat as a hard requirement, Arch installs it
          # system-wide) — without it the shell crash-looped on
          # "module Qt5Compat.GraphicalEffects is not installed" after the
          # 2026-10-10 switch. Same-ABI module: quickshell follows this
          # flake's nixpkgs.
          # ⚠️ Upstream default.nix's passthru.withModules closes over the
          # ORIGINAL wrapper let-binding: (pkg.overrideAttrs f).withModules m
          # and (pkg.override g).withModules m silently DISCARD the override
          # (verified 2026-10-10 — eval returned the stock drv, patches=[]).
          # The wrapper is also a separate derivation (cp -r ${unwrapped}),
          # so package-level patches cannot reach the binary anyway. Hence:
          # patch passthru.unwrapped, then replicate the upstream wrapper
          # verbatim against the patched build (qt5compat folded into
          # buildInputs exactly as withModules would).
          quickshell =
            let
              qs = inputs.quickshell.packages.${final.stdenv.hostPlatform.system}.quickshell;
              qsUnwrapped = qs.unwrapped.overrideAttrs (old: {
                # IconImageProvider::requestPixmap calls the GUI-thread-only
                # Qt icon machinery (QIcon::fromTheme/QIcon::pixmap) from BOTH
                # the main thread (sync IconImage loads, e.g. lucid dock
                # items) and the QQuickPixmapReader thread (async loads) —
                # crash-looped lucid restarts 2026-10-10 (SIGSEGV in
                # QSvgIconEngine + __cxa_pure_virtual in
                # QPlatformPixmap::fromFile, ~/.cache/quickshell/crashes).
                # The patch marshals off-thread requests onto the GUI thread
                # (BlockingQueuedConnection, inline on the GUI thread itself).
                # A plain mutex was tried first and reverted same day: it
                # turned the race into a deadlock — the reader thread wedged
                # inside a request and every icon silently fell back to
                # generics. Drop when upstream fixes
                # #1007/#1028/#1056/#1079 — also restore upstream
                # withModules for qt5compat below.
                patches = (old.patches or [ ]) ++ [ ./quickshell-patches/201-iconprovider-thread-safety.patch ];
              });
            in
            qsUnwrapped.stdenv.mkDerivation {
              inherit (qsUnwrapped) version meta;
              pname = "${qsUnwrapped.pname}-wrapped";

              nativeBuildInputs = qsUnwrapped.nativeBuildInputs ++ [ final.qt6.wrapQtAppsHook ];
              buildInputs = qsUnwrapped.buildInputs ++ [ final.qt6.qt5compat ];

              dontUnpack = true;
              dontConfigure = true;
              dontBuild = true;

              installPhase = ''
                mkdir -p $out
                cp -r ${qsUnwrapped}/* $out
              '';

              passthru.unwrapped = qsUnwrapped;
            };
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
      #   / .virbr0-firewall / .zram-heal / .yoga-s2h-logic
      #   / .nix-media-upgrade-pipeline / .host-units-smoke
      nixosTests.${system} =
        (pkgs.callPackage ./tests/litellm-firewall.nix {
          litellmModule = ./modules/features/litellm.nix;
        })
        // (pkgs.callPackage ./tests/virbr0-firewall.nix {
          virtualizationModule = ./modules/features/virtualization.nix;
          filesystemModule = ./modules/features/filesystem.nix;
        })
        // (pkgs.callPackage ./tests/zram-heal.nix {
          zramModule = ./modules/features/zram.nix;
        })
        // (pkgs.callPackage ./tests/yoga-s2h.nix {
          s2hModule = ./hosts/yoga/yoga-s2h.nix;
          zramModule = ./modules/features/zram.nix;
        })
        // (pkgs.callPackage ./tests/nix-media-pipeline.nix {
          mediaRoleModule = ./modules/roles/media.nix;
          maintenanceModule = ./hosts/nix-media/maintenance.nix;
          ntfyModule = ./hosts/nix-media/ntfy.nix;
          dockerModule = ./hosts/nix-media/docker.nix;
          sopsStubModule = import ./tests/sops-stub.nix;
        })
        // (pkgs.callPackage ./tests/host-units-smoke.nix {
          coreModule = ./modules/core;
          featuresModule = ./modules/features;
          rolesModule = ./modules/roles;
          hardwareModule = ./modules/hardware;
          diskoModule = inputs.disko.nixosModules.disko;
          preloadNgModule = inputs.preload-ng.nixosModules.default;
          homeManagerModule = inputs.home-manager.nixosModules.home-manager;
          latitudeModule = ./hosts/latitude/default.nix;
          sopsStubModule = import ./tests/sops-stub.nix;
          flakeRoot = self.outPath;
          inherit inputs self;
        });

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
