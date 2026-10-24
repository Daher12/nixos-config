{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.features.spotify;

  # SpotX-patched client from the overlay below. The nixpkgs snap-repack
  # wrapper (bin/spotify) already carries LD_LIBRARY_PATH/GIO/GLib env and a
  # hook: with NIXOS_OZONE_WL=1 it unsets DISPLAY, so the CEF/Chromium client
  # auto-detects Wayland and takes its device scale from the compositor.
  spotifySpotx = pkgs.spotify-spotx.override { inherit (cfg) spotxArgs; };

  # Spotify is a CEF client: without this it starts under XWayland at 1x —
  # tiny UI on the scale-2 Hyprland output, with the compositor-compensated
  # cursor looming over it. QT_* vars are no-ops here, and a hardcoded
  # --force-device-scale-factor would double-scale under GNOME (mutter
  # already scales XWayland) and on external 1x monitors. Running native
  # Wayland sidesteps all of that: the scale simply follows the output, in
  # every session. home/default.nix also exports NIXOS_OZONE_WL=1, but
  # home.sessionVariables only reaches processes launched through a shell
  # (hm-session-vars.sh); this wrapper additionally pins it for non-shell
  # launch paths (GNOME activities, lucid's launcher), where that variable
  # may be absent.
  spotifyWayland =
    pkgs.runCommand "spotify-spotx-wayland"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p $out/bin
        makeWrapper ${spotifySpotx}/bin/spotify $out/bin/spotify \
          --inherit-argv0 \
          --set NIXOS_OZONE_WL 1
        ln -s ${spotifySpotx}/share $out/share
      '';
in
{
  options.features.spotify = {
    enable = lib.mkEnableOption "Spotify desktop client patched with SpotX";

    spotxArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra flags passed to the build-time SpotX-Bash patch run (see
        SpotX-Nix README; interactive/client-install options are not
        allowed during a Nix build).
      '';
    };

    nativeWayland = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Launch the client with NIXOS_OZONE_WL=1 scoped to it, so it runs
        native Wayland and inherits the compositor's monitor scale
        (without this it sits under XWayland at 1x — tiny UI, oversized
        cursor on scale-2 outputs). Disable to get the stock XWayland
        launch (e.g. if a client update breaks its Wayland mode).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # SpotX-Nix ships an overlay only: it overrideAttrs-patches the
    # official unfree nixpkgs spotify with SpotX-Bash at build time
    # (allowUnfree already on for every host via lib/mkHost.nix). The
    # overlay sits inside mkIf so hosts with the feature off (nix-media)
    # never even evaluate spotify-spotx.
    #
    # Pin drift: the input follows OUR nixpkgs, but the SpotX-Bash patch
    # script rides SpotX-Nix's own lock. If a nixpkgs bump ships a spotify
    # newer than their pinned SpotX-Bash supports, this build fails loudly
    # ("Nixpkgs Spotify X is newer than SpotX-Bash Y") — fix:
    # `nix flake update spotx-nix` (REPO_OVERVIEW Known Gotchas).
    nixpkgs.overlays = [ inputs.spotx-nix.overlays.default ];

    environment.systemPackages = [
      (if cfg.nativeWayland then spotifyWayland else spotifySpotx)
    ];
  };
}
