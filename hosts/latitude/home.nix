{ ... }:

{
  imports = [
    ../../home
  ];

  # Match system.stateVersion in hosts/latitude/default.nix
  home.stateVersion = "25.05";

  browsers = {
    firefox.enable = true;
    brave.enable = true;
  };

  # Shared config from home/opencode.nix. No impermanence here (plain ext4
  # home) — auth/state persist naturally in ~/.local/share/opencode; log in
  # once with `opencode auth login`.
  opencode.enable = true;
}
