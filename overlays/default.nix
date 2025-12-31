{ inputs }:

let
  # 1. Access to Unstable Packages
  unstable = final: prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

in
{
  # We return a clean list of overlays
  default = [
    unstable
    # You can add more overlays here in the future
  ];
}
