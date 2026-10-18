{ lib, ... }:

{
  features = {
    bluetooth.enable = lib.mkDefault true;
    power-tlp.enable = lib.mkDefault true;
    zram.enable = lib.mkDefault true;
    network-optimization.enable = lib.mkDefault true;
    # Laptops want the zen kernel; the module itself stays opt-in
    # (features.kernel default-true would force it onto every host).
    kernel.enable = lib.mkDefault true;
    kernel.variant = lib.mkDefault "zen";
    oomd.enable = lib.mkDefault true;
    secureboot.enable = lib.mkDefault true;

    vpn.tailscale = {
      enable = lib.mkDefault true;
      routingFeatures = lib.mkDefault "client";
      trustInterface = lib.mkDefault true;
    };

    sops.enable = lib.mkDefault false;

    # Common to both laptops (host copies removed 2026-10-17).
    # serverIp uses the features.nas option default (Tailscale IP of nix-media).
    nas.enable = lib.mkDefault true;

    # Managed Brave policies (/etc/brave/policies/managed/origin.json):
    # Origin mode + debloat.
    brave.enable = lib.mkDefault true;

    # Spotify desktop client, SpotX-patched at build time
    # (modules/features/spotify.nix, spotx-nix flake input).
    spotify.enable = lib.mkDefault true;
  };

  # --- Fleet laptop baseline (host copies removed 2026-10-17) ---
  core = {
    # Byte-identical on both laptops.
    users.description = lib.mkDefault "David";

    # SSH restricted to the home management LAN — accept rule emitted by
    # modules/core/openssh.nix (nftables required, see its description).
    openssh = {
      enable = lib.mkDefault true;
      mgmtLanCidr = lib.mkDefault "192.168.88.0/24";
    };

    boot.silent = lib.mkDefault true;
    nix.gc.automatic = lib.mkDefault true;
  };

  # --- Firewall hardening (activates on next operator `nixos-rebuild
  # switch`; keep console/Tailscale access available before switching) ---
  # Default-deny input (NixOS firewall default policy) with explicit holes:
  # SSH only from the home management LAN (192.168.88.0/24), plus ICMP echo.
  # Loopback and established/related are allowed by the base firewall; the
  # tailscale0 interface stays trusted via
  # features.vpn.tailscale.trustInterface, which remains the
  # remote-management path on foreign networks. Port 22 must NOT re-enter
  # allowedTCPPorts — that would re-open it on every interface.
  #
  # nftables backend (yoga switched 2026-09-13 after a repo-wide check:
  # nothing pins iptables explicitly). CAUTION: enabling this silently
  # auto-flips libvirt's firewall backend to nftables too (nixpkgs
  # default), which broke VM NAT 2026-09 — libvirt is therefore explicitly
  # pinned back to the iptables backend in
  # modules/features/virtualization.nix; its iptables-nft rules
  # (LIBVIRT_* chains) coexist with the native table.
  networking.nftables.enable = lib.mkDefault true;

  services = {
    openssh.openFirewall = lib.mkDefault false;

    # useStockConfig = true: the stock config already enables cfsProfiles
    # and the foreground/PipeWire process boosts — settings.* is documented
    # as ignored while the stock config is on, so none are set here.
    system76-scheduler = {
      enable = lib.mkDefault true;
      useStockConfig = lib.mkDefault true;
    };

    logind.settings.Login = {
      HandleLidSwitch = lib.mkDefault "suspend";
      HandleLidSwitchExternalPower = lib.mkDefault "ignore";
      HandleLidSwitchDocked = lib.mkDefault "ignore";
    };
  };
}
