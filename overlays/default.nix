{ pkgs-unstable }:

let
  # Unstable packages overlay - uses memoized import from flake.nix
  unstable = _: _: {
    unstable = pkgs-unstable;
  };
in
{
  default = [
    unstable
  ];
}
