{ inputs, pkgs-unstable }:

let
  # Unstable packages overlay - uses memoized import from flake.nix
  unstable = final: prev: {
    unstable = pkgs-unstable;
  };
in
{
  default = [
    unstable
  ];
}
