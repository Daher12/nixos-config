{ lib, ... }:

{
  features.office = {
    enable = lib.mkDefault true;
    vclPlugin = lib.mkDefault "gtk3";
  };
}
