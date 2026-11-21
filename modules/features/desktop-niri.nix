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

  # The session's Noctalia binary (same package the HM shell service runs —
  # its IPC socket is what we talk to).
  noctaliaPackage = config.home-manager.users.${mainUser}.programs.noctalia.package;

  # Locks the session once the Noctalia shell is up after greetd autologin.
  # Uptime-gated so only the autologin boot locks: a session starting later
  # (logout -> greeter login, rebuild-test session bounces) already had an
  # authentication and must not be asked for the password twice. The
  # noctalia user service being started does not guarantee its IPC socket
  # is listening yet, so retry briefly. `noctalia msg session lock` is the
  # same IPC the Mod+L bind uses (home/niri.nix).
  noctaliaLockAtBoot = pkgs.writeShellScript "noctalia-lock-at-boot" ''
    if [ "$(${pkgs.coreutils}/bin/cut -d. -f1 /proc/uptime)" -ge 240 ]; then
      exit 0
    fi
    i=0
    until ${noctaliaPackage}/bin/noctalia msg session lock; do
      i=$((i + 1))
      [ "$i" -ge 50 ] && exit 1
      ${pkgs.coreutils}/bin/sleep 0.2
    done
  '';
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
      exclusive with features.desktop-gnome — switch via the flake attrs:
      yoga = niri, yoga-gnome = GNOME)
    '';

    greeter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "noctalia-greeter login screen (greetd-backed; bundles its own wlroots compositor, lists the installed Wayland sessions)";
      };

      autoLogin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Boot straight into the niri session (greetd initial_session)
          instead of showing the greeter first, gated by the Noctalia lock
          screen.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = !config.features.desktop-gnome.enable;
            message = "features.desktop-niri and features.desktop-gnome are mutually exclusive — switch via the flake attrs (yoga = niri, yoga-gnome = GNOME)";
          }
        ];

        # niri session + portals (xdg-desktop-portal-gnome for screencast,
        # gtk fallback), gnome-keyring, and the niri systemd user units.
        # niri 26.04 integrates with systemd natively: the session entry
        # runs niri-session, which imports the environment into the user
        # manager and starts niri.service (BindsTo=graphical-session.target)
        # — no external session wrapper needed. The Noctalia shell rides
        # that target as a home-manager user service (home/noctalia.nix).
        programs.niri.enable = true;

        # niri-session 26.04 imports the login environment with a bare
        # `systemctl --user import-environment` — deprecated since systemd
        # 260, printing a one-line warning to stderr. Under autologin,
        # greetd runs niri-session on the bare VT1, so that warning IS the
        # one-line TTY flash before niri's first frame (2026-11-19; greeter
        # boots never showed it — the screen was already in graphics mode
        # through the greeter handoff). Mirror the upstream-main fix until
        # nixpkgs' niri carries it: dbus-update-activation-environment
        # --systemd --all updates the DBus activation env AND the user
        # manager (same net effect, no warning). The bare import stays only
        # as the no-dbus-tools fallback — neutered to a no-op here, the
        # tool ships in the system path on every NixOS. --replace-fail
        # trips the build the moment the upstream script changes.
        programs.niri.package = pkgs.niri.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace resources/niri-session \
              --replace-fail "systemctl --user import-environment" ":" \
              --replace-fail "dbus-update-activation-environment --all" \
              "dbus-update-activation-environment --systemd --all"
          '';
        });

        # Battery widget / power info (not covered by the shell's HM module).
        services.upower.enable = true;

        # GNOME-style GTK apps the binds and float rules rely on (same
        # block as the GNOME attr). No hyprpolkitagent: Noctalia
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
          # media keys) — without them here the FN keys are dead.
          brightnessctl
          playerctl
          pulseaudio
        ];

        # gnome-keyring: PAM auto_start wires the daemon into both session
        # stacks — the greeter login (greetd service) and Noctalia
        # lock-screen unlocks (PAM "login", hardcoded in the lock screen).
        # Two limits, learned 2026-11-19 (the FIRST autologin boot ever —
        # not the nixpkgs bump it coincided with; every earlier boot went
        # through the greeter, whose password silently unlocked everything,
        # journal-proven): (1) greetd's initial_session carries no PAM
        # authtok, so an autologin boot starts with everything locked;
        # (2) pam_gnome_keyring only ever unlocks the LOGIN keyring anyway.
        # Noctalia's network secret agent reads the DEFAULT collection
        # (Default_keyring, the WiFi secrets) right at shell start, which
        # then pops a GCR "Schlüsselbund entsperren" dialog ahead of the
        # boot lock screen. Resolution: Default_keyring is deliberately
        # password-less (user-run seahorse change, 2026-11-19) —
        # gnome-keyring auto-unlocks empty-password collections when the
        # Secret service starts, so the shell reads silently and the lock
        # screen stays the only prompt. login.keyring keeps its password.
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
        # handoff is still in flight.
        users.users.greeter.extraGroups = [ "video" ];

        # The niri session entry ships with programs.niri ("niri" desktop
        # file, niri-session based — see the systemd note above).
        services.displayManager.defaultSession = "niri";
      })

      (lib.mkIf (cfg.greeter.enable && cfg.greeter.autoLogin) {
        # greetd runs the niri session as initial_session at boot. The
        # upstream greeter module only sets default_session — it does NOT
        # translate services.displayManager.autoLogin, so this is wired
        # directly. niri-session is the same entry
        # the "niri" desktop file runs: it imports the environment into the
        # user manager and starts niri.service, and the Noctalia shell rides
        # graphical-session.target behind it. initial_session only fires at
        # boot — after logout greetd falls back to default_session (the
        # greeter above).
        services.greetd.settings.initial_session = {
          command = "${config.programs.niri.package}/bin/niri-session";
          user = mainUser;
        };

        # Autologin boots into a running session; authentication (and
        # gnome-keyring unlock) moves to the Noctalia lock screen — unlock
        # goes through PAM service "login", already keyring-wired above.
        # The After= below is load-bearing: a unit wanted by a target with
        # no ordering of its own would get an implicit After= FROM the
        # target and stall the boot (~10 s per autologin boot, 2026-09-25).
        home-manager.users.${mainUser}.systemd.user.services.noctalia-lock-at-boot = {
          Unit = {
            Description = "Lock the session after greetd autologin (auth moves to the Noctalia lock screen)";
            After = [ "graphical-session.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${noctaliaLockAtBoot}";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      })
    ]
  );
}
