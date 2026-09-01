{ pkgs, lib, ... }:
{
  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = lib.mkDefault "de_DE.UTF-8";

  console = {
    earlySetup = lib.mkDefault true;
    font = lib.mkDefault "ter-v16n";
    packages = lib.mkDefault [ pkgs.terminus_font ];
    useXkbConfig = lib.mkDefault true;
  };
}
