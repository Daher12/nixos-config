{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.features.spotify;
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
  };

  config = lib.mkIf cfg.enable {
    # SpotX-Nix ships an overlay only: it overrideAttrs-patches the
    # official unfree nixpkgs spotify with SpotX-Bash at build time
    # (allowUnfree already on for every host via lib/mkHost.nix). The
    # overlay sits inside mkIf so hosts with the feature off (nix-media)
    # never even evaluate spotify-spotx.
    nixpkgs.overlays = [ inputs.spotx-nix.overlays.default ];

    environment.systemPackages = [
      (pkgs.spotify-spotx.override { inherit (cfg) spotxArgs; })
    ];
  };
}
