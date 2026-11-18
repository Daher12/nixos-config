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
    # pin resumed moving at v2.1.4 (2026-10-24 sweep), reached v2.2.0 in the
    # 2026-10-28 sweep and v2.2.4 in the 2026-10-31 sweep (gate:
    # `nix build github:anomalyco/opencode/v2.2.N` clean before touching this
    # tag — keep that gate per bump; v2.2.5 is SKIPPED: its vendored
    # node_modules.nix hash mismatches the lockfile it ships — upstream
    # packaging bug, caught by this gate 2026-10-31; v2.2.6 AND v2.2.7
    # SKIPPED the same way 2026-11-12 — same fetchNpmDeps hash mismatch in
    # their shipped packaging, gate re-tried them first. v2.3.0, v2.3.1 AND
    # v2.3.2 SKIPPED the same way 2026-11-18 — all three gate-fail with the
    # same stale node_modules hash (specified sha256-UOVs48Z4… matches none
    # of the three shipped lockfiles; got zOej…/At90…/At90… respectively) —
    # upstream's vendored hash hasn't been regenerated since 2.2.4. Six
    # consecutive broken releases; pin held at v2.2.4.
    # Deliberately NO `nixpkgs.follows` here: upstream requires its pinned
    # nixpkgs-unstable (packageManager bun@1.4.2; nixos-26.05 only ships
    # bun 1.3.13, whose `bun install` fails extracting the big native
    # tarballs and hangs the build). Cost: its own nixpkgs eval (nixpkgs_4
    # in the lock) — the lock carries four in total (base, noctalia's,
    # the greeter's, this one), each documented at its input.
    # The libstdc++ LD_LIBRARY_PATH wrap in home/opencode.nix covers the
    # resulting stdenv mismatch.
    opencode = {
      url = "github:anomalyco/opencode/v2.2.4";
    };

    # Spotify desktop client patched with SpotX (ad blocking) at build
    # time. Overlay-only upstream flake (no NixOS/HM module), consumed by
    # modules/features/spotify.nix. Manual pin (update-safe never touches
    # it): the
    # upstream bot re-aligns SpotX-Bash with nixpkgs' spotify every ~6 h,
    # and we follow OUR nixpkgs — if a nixpkgs bump outpaces their pin,
    # the spotify-spotx build fails loudly ("Nixpkgs Spotify X is newer
    # than SpotX-Bash Y"). Fix: `nix flake update spotx-nix`. Deliberately
    # NOT in the update-safe list.
    spotx-nix = {
      url = "github:SpotX-Official/SpotX-Nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia — the C++ Wayland shell (bar, launcher, notifications, lock
    # screen, idle, clipboard, wallpaper, polkit agent) the niri session
    # runs on yoga in place of the retired Hyprland/lucid stack (modules/
    # features/desktop-niri.nix + home/noctalia.nix). Not in nixpkgs →
    # flake. Pinned
    # to release tags (stable-tags-only), bump deliberately with
    # `nix flake update noctalia noctalia-greeter`, then smoke-test shell
    # AND greeter together. Deliberately NO nixpkgs follows on either input:
    # the upstream docs state a follows disables the binary cache
    # (noctalia.cachix.org, modules/core/nix.nix) and both are built against
    # their own pinned nixpkgs — the price is one extra nixpkgs eval per
    # input (nixpkgs_2 + nixpkgs_3; four evals total with base + opencode's).
    noctalia.url = "github:noctalia-dev/noctalia/v5.5.0";
    # Paired greetd greeter (own bundled wlroots compositor, no session
    # compositor needed): nixosModules.default imported in desktop-niri.nix.
    noctalia-greeter.url = "github:noctalia-dev/noctalia-greeter/v1.7.0";
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

      # VM tests — run via `scripts/test-suite vm` (agent gate protocol in
      # AGENTS.md § Verification workflow (QC)), not part of `checks` (CI
      # stays fast). Direct form:
      # nix build .#nixosTests.x86_64-linux.<litellm-gateway|ssh-firewall
      #   |virbr0-firewall|zram-heal|yoga-s2h-logic
      #   |nix-media-upgrade-pipeline|host-units-smoke>
      nixosTests.${system} =
        (pkgs.callPackage ./tests/litellm-firewall.nix {
          litellmModule = ./modules/features/litellm.nix;
          opensshModule = ./modules/core/openssh.nix;
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

      nixosConfigurations =
        let
          # Shared argset for both yoga attrs (the desktop profiles are the
          # only field that differs — see yoga-gnome below).
          yogaArgs = {
            hostname = "yoga";
            mainUser = "dk";
            withHardware = true; # Enables /modules/hardware evaluation
            profiles = [
              "laptop"
              "desktop-niri"
            ];
            extraModules = [
              inputs.nixos-hardware.nixosModules.lenovo-yoga-7-slim-gen8
              ./hosts/yoga/default.nix
            ];
            hmModules = [ ./hosts/yoga/home.nix ];
          };
        in
        {
          # Physical Laptop: Yoga (AMD) — niri + Noctalia + noctalia-greeter.
          # Desktop switch (no config edits): rebuild from .#yoga-gnome for GNOME.
          yoga = mkHost yogaArgs;

          # Same machine, GNOME desktop (GDM) — the backup DE for when niri
          # does not fit. Switch targets, nothing else differs.
          yoga-gnome = mkHost (
            yogaArgs
            // {
              profiles = [
                "laptop"
                "desktop-gnome"
              ];
            }
          );

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
              ./hosts/latitude/default.nix
            ];
            hmModules = [ ./hosts/latitude/home.nix ];
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
          };
        };
    };
}
