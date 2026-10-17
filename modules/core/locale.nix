{ pkgs, lib, ... }:
{
  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = lib.mkDefault "de_DE.UTF-8";

  # German layout for X/Wayland sessions and — via console.useXkbConfig
  # below — the virtual consoles, including the systemd-stage-1 LUKS prompt.
  # Lives in core so headless and Hyprland hosts get a de console too; the
  # old GNOME-only placement left yoga/nix-media consoles on the default us.
  services.xserver.xkb.layout = lib.mkDefault "de";

  console = {
    earlySetup = lib.mkDefault true;
    font = lib.mkDefault "ter-v16n";
    packages = lib.mkDefault [ pkgs.terminus_font ];
    useXkbConfig = lib.mkDefault true;
  };
}
