{
  config,
  lib,
  pkgs,
  mainUser,
  ...
}:

let
  cfg = config.features.desktop-niri;
in
{
  # The dux-greeter (programs.dms-greeter) and dux-shell
  # (programs.dank-material-shell) modules are imported unconditionally in
  # desktop-hyprland.nix — which every host evaluates via
  # modules/features/default.nix — so their options exist here without a
  # second import (importing the same flake-module attrset twice does NOT
  # dedupe: each evaluation yields a fresh module identity and the option
  # declarations collide, breaking every host). Config is gated behind
  # cfg.enable below. The upstream DMS home-manager module is NOT imported
  # anywhere (it assigns programs.quickshell, defined nowhere) — the HM
  # side (settings seed + grayscale theme) lives in home/dms.nix.

  options.features.desktop-niri = {
    enable = lib.mkEnableOption ''
      niri desktop with the DMS session shell and DankGreeter (mutually
      exclusive with features.desktop-hyprland and features.desktop-gnome —
      switch via the flake attrs: yoga = Hyprland, yoga-gnome = GNOME,
      yoga-niri = niri)
    '';

    greeter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "DankGreeter login screen (greetd-backed, running on the niri compositor)";
      };

      configHome = lib.mkOption {
        type = lib.types.str;
        default = "/home/${mainUser}";
        description = "Home whose DMS settings theme the greeter (configHome must be readable at greeter time)";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = !config.features.desktop-hyprland.enable;
            message = "features.desktop-niri and features.desktop-hyprland are mutually exclusive — switch via the flake attrs (yoga = Hyprland, yoga-gnome = GNOME, yoga-niri = niri)";
          }
          {
            assertion = !config.features.desktop-gnome.enable;
            message = "features.desktop-niri and features.desktop-gnome are mutually exclusive — switch via the flake attrs (yoga = Hyprland, yoga-gnome = GNOME, yoga-niri = niri)";
          }
        ];

        # niri session + portals (xdg-desktop-portal-gnome for screencast,
        # gtk fallback), gnome-keyring, and the niri systemd user units.
        # niri 26.04 integrates with systemd natively: the session entry
        # runs niri-session, which imports the environment into the user
        # manager and starts niri.service (BindsTo=graphical-session.target)
        # — no uwsm needed (Hyprland needs uwsm precisely because it lacks
        # this integration).
        programs.niri.enable = true;

        # DMS session shell: the upstream module wires the dms user service
        # (PartOf/After/WantedBy graphical-session.target — starts as soon
        # as the niri session pulls the target up), quickshell (overlaid
        # pkgs.quickshell — patch 201 rides along) and its runtime deps, and
        # sets accounts-daemon/power-profiles-daemon/geoclue2/polkit via
        # mkDefault (TLP's explicit power-profiles-daemon.enable = false
        # still wins, so TLP keeps owning power management).
        programs.dank-material-shell = {
          enable = true;
          systemd.enable = true;
        };

        # DMS battery widget (not covered by the upstream module).
        services.upower.enable = true;

        # GNOME-style GTK apps the binds and float rules rely on (mirror of
        # the desktop-hyprland block; hyprpolkitagent omitted — DMS ships
        # its own polkit session agent via the dms package).
        services.gvfs.enable = true;
        environment.systemPackages = with pkgs; [
          nautilus
          loupe
          file-roller
          gnome-text-editor
          gnome-calculator
          wl-clipboard
          # Clipboard history backend (wl-paste --watch cliphist store is
          # spawned at niri startup, home/niri.nix).
          cliphist
        ];

        # gnome-keyring unlocks at the greeter login (PAM service of the
        # greetd-backed DankGreeter) and at DMS lock-screen unlocks (PAM
        # service "login", the DMS lock screen's default).
        security.pam.services.greetd.enableGnomeKeyring = true;
        security.pam.services.login.enableGnomeKeyring = true;

        # Home-manager side: flip home/niri.nix (compositor config) and
        # home/dms.nix (shell settings seed + grayscale theme) on.
        home-manager.users.${mainUser}.desktop = {
          niri.enable = lib.mkDefault true;
          dms.enable = lib.mkDefault true;

          # battery-refresh (enabled in the shared hosts/yoga/home.nix) has
          # Hyprland and GNOME backends only; on niri it would pick the
          # GNOME daemon and fail against the mutter-less session. Disabled
          # until a niri backend (niri msg output) is written — the trial
          # runs at the panel's native refresh rate.
          battery-refresh.enable = lib.mkForce false;
        };
      }

      (lib.mkIf cfg.greeter.enable {
        # DankGreeter (same standalone Go binary + upstream module as the
        # Hyprland desktop), here running on the niri compositor — the
        # upstream module's compositor enum includes niri natively.
        programs.dms-greeter = {
          enable = true;
          package = pkgs.dms-greeter;
          compositor.name = "niri";
          configHome = cfg.greeter.configHome;
        };
        # DRM access for the greeter's niri while the logind seat handoff
        # is still in flight (mirrors the desktop-hyprland greeter user).
        users.users.greeter.extraGroups = [ "video" ];

        # The niri session entry ships with programs.niri ("niri" desktop
        # file, niri-session based — see the systemd note above).
        services.displayManager.defaultSession = "niri";
      })
    ]
  );
}
