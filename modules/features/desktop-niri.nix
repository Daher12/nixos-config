{
  config,
  lib,
  pkgs,
  mainUser,
  inputs,
  ...
}:

let
  cfg = config.features.desktop-niri;
in
{
  imports = [
    # noctalia-greeter's NixOS module
    # (services.displayManager.noctalia-greeter; the package defaults to
    # the flake input's own build). Imported ONCE, here — importing the
    # same flake-module attrset from two repo modules does NOT dedupe (each
    # evaluation yields a fresh module identity and the option declarations
    # collide, breaking every host). Config is gated behind cfg.enable
    # below. The Noctalia shell itself is home-manager side
    # (home/noctalia.nix, upstream homeModules.default).
    inputs.noctalia-greeter.nixosModules.default
  ];

  options.features.desktop-niri = {
    enable = lib.mkEnableOption ''
      niri desktop with the Noctalia shell and noctalia-greeter (mutually
      exclusive with features.desktop-hyprland and features.desktop-gnome —
      switch via the flake attrs: yoga = Hyprland, yoga-gnome = GNOME,
      yoga-niri = niri)
    '';

    greeter.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "noctalia-greeter login screen (greetd-backed; bundles its own wlroots compositor, lists the installed Wayland sessions)";
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
        # this integration). The Noctalia shell rides that target as a
        # home-manager user service (home/noctalia.nix).
        programs.niri.enable = true;

        # Battery widget / power info (not covered by the shell's HM module).
        services.upower.enable = true;

        # GNOME-style GTK apps the binds and float rules rely on (mirror of
        # the desktop-hyprland block). No hyprpolkitagent: Noctalia
        # registers its own polkit agent (shell.polkit_agent). No cliphist:
        # Noctalia keeps its own clipboard history.
        services.gvfs.enable = true;
        environment.systemPackages = with pkgs; [
          nautilus
          loupe
          file-roller
          gnome-text-editor
          gnome-calculator
          wl-clipboard
          # X11 apps: niri >= 25.08 spawns xwayland-satellite from PATH on
          # demand (no KDL config needed) — without the package X11 clients
          # just fail to open.
          xwayland-satellite
          # Noctalia's gtk templates gsettings-select adw-gtk3(-dark) and
          # overlay the palette via noctalia.css (home/theme.nix pins the
          # same theme in settings.ini); the template's theme lookup scans
          # XDG_DATA_DIRS, which current-system/sw/share covers.
          adw-gtk3
          # The XF86 binds in home/niri.nix spawn these (volume/brightness/
          # media keys). On the Hyprland attr they ride the lucid/dms
          # package blocks, which this attr does not enable — without them
          # here the FN keys are dead.
          brightnessctl
          playerctl
          pulseaudio
        ];

        # gnome-keyring unlocks at the greeter login (PAM service of the
        # greetd-backed greeter) and at Noctalia lock-screen unlocks (PAM
        # service "login", hardcoded in the lock screen).
        security.pam.services.greetd.enableGnomeKeyring = true;
        security.pam.services.login.enableGnomeKeyring = true;

        # Home-manager side: flip home/niri.nix (compositor config) and
        # home/noctalia.nix (shell) on. battery-refresh (enabled in the
        # shared hosts/yoga/home.nix) picks its niri backend off
        # desktop.niri.enable — same 120↔60 Hz contract as the other
        # sessions.
        home-manager.users.${mainUser}.desktop = {
          niri.enable = lib.mkDefault true;
          noctalia.enable = lib.mkDefault true;
        };
      }

      (lib.mkIf cfg.greeter.enable {
        # The upstream module enables greetd (default_session =
        # noctalia-greeter-session, its bundled wlroots compositor),
        # AccountsService and polkit, and symlinks greeter.toml into
        # /var/lib/noctalia-greeter. Appearance (wallpaper, palette, font,
        # outputs) is synced from the running shell through pkexec; the
        # polkit rule below lets the main user do that without a password
        # (constrained appearance-only operation, never session commands).
        services.displayManager.noctalia-greeter = {
          enable = true;
          settings = {
            # Desktop-entry Name of the niri session (programs.niri).
            session.default = "Niri";
            # Fleet keymap (modules/core/locale.nix, home/niri.nix parity).
            keyboard = {
              layout = "de";
              variant = "nodeadkeys";
            };
            # Same cursor as the session (home/theme.nix).
            cursor = {
              theme = "Posy_Cursor_Black";
              size = 32;
              path = pkgs.posy-cursors;
            };
          };
          passwordless-sync-users = [ mainUser ];
        };
        # DRM access for the greeter's compositor while the logind seat
        # handoff is still in flight (mirrors the desktop-hyprland greeter
        # user).
        users.users.greeter.extraGroups = [ "video" ];

        # The niri session entry ships with programs.niri ("niri" desktop
        # file, niri-session based — see the systemd note above).
        services.displayManager.defaultSession = "niri";
      })
    ]
  );
}
