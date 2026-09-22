{
  config,
  lib,
  pkgs,
  mainUser,
  inputs,
  ...
}:

let
  cfg = config.features.desktop-hyprland;

  # Locks the session once the DMS shell is up after greetd autologin.
  # Uptime-gated so only the autologin boot locks: a session starting later
  # (logout -> greeter login, rebuild-test session bounces) already had an
  # authentication and must not be asked for the password twice. DMS has no
  # lock-on-startup setting, hence the IPC call; dms.service being started
  # does not guarantee its IPC socket is listening yet, so retry briefly.
  dmsLockAtBoot = pkgs.writeShellScript "dms-lock-at-boot" ''
    if [ "$(${pkgs.coreutils}/bin/cut -d. -f1 /proc/uptime)" -ge 240 ]; then
      exit 0
    fi
    i=0
    until ${pkgs.dms-shell}/bin/dms ipc call lock lock; do
      i=$((i + 1))
      [ "$i" -ge 50 ] && exit 1
      ${pkgs.coreutils}/bin/sleep 0.2
    done
  '';
in
{
  # DankGreeter's module is imported unconditionally (option declarations
  # only — programs.dms-greeter); its config is gated behind
  # cfg.greeter.enable below.
  imports = [ inputs.dank-greeter.nixosModules.default ];

  options.features.desktop-hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop with DankMaterialShell and DankGreeter (mutually exclusive with features.desktop-gnome)";

    withUWSM = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Launch Hyprland through uwsm for proper systemd session targets. Also required to scope DMS to the Hyprland session only.";
    };

    dms = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "DankMaterialShell desktop shell (bar, launcher, notifications, lock screen, idle, wallpapers)";
      };

      systemdTarget = lib.mkOption {
        type = lib.types.str;
        default = "graphical-session.target";
        description = ''
          User target that pulls in dms.service. Keep this at the package
          default (graphical-session.target) — scoping to a uwsm session
          target does NOT work: dms.service carries After=graphical-session.target
          (plus Requisite), and modern systemd orders a target after the units
          it pulls in, so a uwsm instance target (which uwsm orders BEFORE
          graphical-session.target) closes an ordering cycle and systemd
          silently deletes the dms.service start job (observed live
          2026-09-21: no bar, no lock, dead dms-ipc keybinds). Scoping is
          still correct: the unit's Requisite=graphical-session.target keeps
          it out of non-graphical sessions, uwsm's stop propagation ends it
          with the Hyprland session, and dms-shell only exists on the
          Hyprland attr anyway.
        '';
      };
    };

    greeter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "DankGreeter login screen (greetd-backed, runs on Hyprland, themed from the user's DMS settings)";
      };

      configHome = lib.mkOption {
        type = lib.types.str;
        default = "/home/${mainUser}";
        description = "Home whose DankMaterialShell settings theme the greeter (configHome must be readable at greeter time)";
      };

      autoLogin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Boot straight into the uwsm Hyprland session (greetd initial_session)
          instead of showing the greeter first, gated by the DMS lock screen.
          This removes the greeter-to-session handoff: only one compositor ever
          starts, so there is no VT/console flash at login. Authentication (and
          gnome-keyring unlock) happens at the DMS lock screen on first unlock;
          the greeter still runs after logout and whenever the initial session
          exits.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = builtins.hasAttr "home-manager" config;
            message = "features.desktop-hyprland requires home-manager to be included via mkHost";
          }
          {
            assertion = !config.features.desktop-gnome.enable;
            message = "features.desktop-hyprland and features.desktop-gnome are mutually exclusive — switch via the flake attrs (yoga = Hyprland, yoga-gnome = GNOME)";
          }
          {
            assertion = !cfg.greeter.autoLogin || cfg.dms.enable;
            message = "features.desktop-hyprland.greeter.autoLogin requires dms.enable — the DMS lock screen is the authentication gate";
          }
        ];

        # Registers the Hyprland session for the greeter and adds the
        # Hyprland portal.
        programs.hyprland = {
          enable = true;
          withUWSM = lib.mkDefault cfg.withUWSM;
          xwayland.enable = lib.mkDefault true;
        };

        # GUI privilege prompts (GNOME Shell is not around to provide one;
        # DMS does not ship an agent either).
        environment.systemPackages = with pkgs; [
          hyprpolkitagent
          # Handful of GTK apps the Hyprland session relies on (previously
          # pulled in by desktop-gnome): file manager + viewers used by the
          # binds and float rules in home/hyprland.nix.
          nautilus
          loupe
          file-roller
          gnome-text-editor
          gnome-calculator
          wl-clipboard
          # Clipboard history backend for the DMS clipboard modal
          # (wl-paste --watch cliphist store is autostarted in home/hyprland.nix).
          cliphist
        ];

        # Nautilus trash/mount support, dconf for home-manager theme settings.
        services.gvfs.enable = true;
        programs.dconf.enable = lib.mkDefault true;

        # Secrets: gnome-keyring with unlock at greeter login (PAM service of
        # the greetd-backed DankGreeter).
        services.gnome.gnome-keyring.enable = true;
        security.pam.services.greetd.enableGnomeKeyring = true;

        # File dialogs etc. without the GNOME portal: Hyprland portal (added
        # by programs.hyprland) + gtk portal.
        xdg.portal = {
          enable = true;
          extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        };

        # Flip the home-manager side (Lua config) on for the user, mirroring
        # how desktop-gnome pushes dconf settings down.
        home-manager.users.${mainUser}.desktop.hyprland.enable = lib.mkDefault true;
      }

      (lib.mkIf cfg.dms.enable {
        programs.dms-shell = {
          enable = true;
          systemd = {
            enable = true;
            target = cfg.dms.systemdTarget;
          };
          # Wallpaper-driven colors: matugen recolors the DMS shell, GTK and
          # Firefox from the current wallpaper. darkman + switch-theme are
          # auto-disabled on this attr (home/theme.nix) so they don't fight
          # matugen over ~/.config/gtk-4.0 and GTK_THEME. A static Nord DMS
          # theme stays shipped (home/hyprland.nix) as the fallback for when
          # you turn dynamic theming off in DMS Settings.
          enableDynamicTheming = true;
          # No khal/vdirsyncer calendar backend in use.
          enableCalendarEvents = false;
        };

        # TLP (laptop profile) owns power management; power-profiles-daemon
        # (mkDefault true via programs.dms-shell) would conflict with it.
        services.power-profiles-daemon.enable = false;

        # DMS's battery bar widget and control-center pill read battery
        # state from org.freedesktop.UPower; without the daemon they render
        # empty ("No battery"). Pure monitoring — does not touch TLP's
        # CPU/platform-profile management.
        services.upower.enable = true;
      })

      (lib.mkIf cfg.greeter.enable {
        # DankGreeter, split out of the shell in DMS 1.6.0: standalone Go
        # binary + upstream NixOS module (github:AvengeMedia/dank-greeter),
        # newer than the greeter baked into nixpkgs 26.05's dms-shell 1.4.6
        # (services.displayManager.dms-greeter stays unused). Package =
        # binary-cached unstable build via the flake overlay. The greeter
        # user is provided by the greetd module (default_session.user
        # defaults to "greeter" and the user is created for us).
        programs.dms-greeter = {
          enable = true;
          package = pkgs.dms-greeter;
          compositor.name = "hyprland";
          configHome = cfg.greeter.configHome;
        };
        # DRM access for the greeter's Hyprland while the logind seat
        # handoff is still in flight (mirrors the old nixpkgs module's user).
        users.users.greeter.extraGroups = [ "video" ];

        # Two session entries ship with hyprland ("hyprland" bare and
        # "hyprland-uwsm"). Preselect the uwsm one: dms.service is bound to
        # the uwsm session target, which only the uwsm session activates —
        # picking the bare session would start Hyprland without DMS.
        services.displayManager.defaultSession = "hyprland-uwsm";
      })

      (lib.mkIf cfg.greeter.autoLogin {
        # greetd runs the uwsm Hyprland session as initial_session at boot
        # (dms-greeter module wires this from the generic autoLogin options;
        # autologinSession resolves to defaultSession = "hyprland-uwsm").
        services.displayManager.autoLogin = {
          enable = true;
          user = mainUser;
        };

        # The DMS lock screen authenticates against "dankshell" when
        # /etc/pam.d/dankshell exists (fallback: "login"). With autologin no
        # password is entered at session start, so the keyring stays locked
        # until the first screen unlock — wire pam_gnome_keyring into the
        # lock screen so that unlock opens the login keyring too (works while
        # keyring and login passwords match).
        security.pam.services.dankshell.enableGnomeKeyring = true;

        # Autologin boots into a running session; lock it as soon as the DMS
        # shell can show its lock screen. NO After=dms.service here: ordered
        # after dms while being wanted by the same target re-creates the
        # ordering cycle that keeps DMS from starting — the script's own
        # retry loop already tolerates a not-yet-ready shell.
        home-manager.users.${mainUser}.systemd.user.services.dms-lock-at-boot = {
          Unit = {
            Description = "Lock the session after greetd autologin (auth moves to the DMS lock screen)";
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${dmsLockAtBoot}";
          };
          Install.WantedBy = [ cfg.dms.systemdTarget ];
        };
      })
    ]
  );
}
