# Fleet SSH public keys — the single source for the authorizedKeys
# literals hosts declare (consumed as the `fleetKeys` specialArg, wired in
# lib/mkHost.nix). PUBLIC key material only: never add secret material
# here (secrets go through sops-nix).
{
  dk-yoga = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE900h7UUGyAcICSsxmX2xqEDcF1PTkonC/r9l3xroES dk@yoga";
}
