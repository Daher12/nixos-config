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

  # Locks the session once the Lucid shell is up after greetd autologin.
  # Uptime-gated so only the autologin boot locks: a session starting later
  # (logout -> greeter login, rebuild-test session bounces) already had an
  # authentication and must not be asked for the password twice. lucidlock
  # exposes the IPC shape `qs ipc call lock lock` (Lockscreen.qml IPC handler
  # "lock"); lucid.service being started does not guarantee its IPC socket is
  # listening yet, so retry briefly.
  lucidLockAtBoot = pkgs.writeShellScript "lucid-lock-at-boot" ''
    if [ "$(${pkgs.coreutils}/bin/cut -d. -f1 /proc/uptime)" -ge 240 ]; then
      exit 0
    fi
    i=0
    until ${pkgs.quickshell}/bin/qs ipc call lock lock; do
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
    enable = lib.mkEnableOption "Hyprland desktop with the Lucid shell and DankGreeter (mutually exclusive with features.desktop-gnome)";

    withUWSM = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Launch Hyprland through uwsm for proper systemd session targets.";
    };

    lucid = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Lucid desktop shell (Material 3 Expressive Quickshell shell).
          Deploys the upstream source into ~/.config/quickshell via a
          home-manager activation sync (home/lucid.nix — Lucid has no Nix
          packaging and keeps runtime settings inside its shell directory)
          and provides the user services, PAM/keyring wiring and deps.
          DankGreeter (greeter.enable) stays: it is a standalone binary.
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
          instead of showing the greeter first, gated by the Lucid lock screen.
          This removes the
          greeter-to-session handoff: only one compositor ever starts, so
          there is no VT/console flash at login. Authentication (and
          gnome-keyring unlock) happens at the lock screen on first unlock;
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
            assertion = !cfg.greeter.autoLogin || cfg.lucid.enable;
            message = "features.desktop-hyprland.greeter.autoLogin requires lucid.enable — the shell lock screen is the authentication gate";
          }
        ];

        # Registers the Hyprland session for the greeter and adds the
        # Hyprland portal.
        programs.hyprland = {
          enable = true;
          withUWSM = lib.mkDefault cfg.withUWSM;
          xwayland.enable = lib.mkDefault true;
        };

        # GUI privilege prompts for non-lucid sessions (GNOME Shell is not
        # around to provide one); on the lucid attr Lucid itself is the
        # session agent — this package stays as a manual fallback.
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
          # Clipboard history backend for lucid's launcher clipboard search
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
        # "hyprland-uwsm"). Preselect the uwsm one: only the uwsm session
        # activates the proper systemd session targets the user services
        # (lucid.service etc.) ride on — the bare session starts Hyprland
        # without them.
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

        # Autologin boots into a running session; authentication (and
        # gnome-keyring unlock) moves to the shell lock screen — the lucid
        # block below arms lucid-lock-at-boot and wires pam_gnome_keyring
        # into the lock screen's PAM service ("login").
      })

      (lib.mkIf cfg.lucid.enable {
        # Lucid replaces only the user-session shell; the greeter stack
        # (greeter.enable block above) is untouched. DankGreeter keeps
        # theming itself from the persisted ~/.config/DankMaterialShell
        # settings (cosmetic staleness, by design).

        # Lucid's battery widget reads org.freedesktop.UPower; Users.qml
        # (lock-screen user list/avatar) talks to accountsservice. Pure
        # monitoring/lookup — TLP still owns power management (which is why
        # power-profiles-daemon stays off).
        services = {
          upower.enable = true;
          accounts-daemon.enable = true;
          power-profiles-daemon.enable = false;
        };

        # polkitd backend for lucidpolkit: the shell IS the session's polkit
        # agent (upstream install.sh: "polkitd and its setuid helper are the
        # backend it drives"). hyprpolkitagent stays installed as a manual
        # fallback but is no longer autostarted (home/hyprland.nix).
        security.polkit.enable = true;

        # The lucid lock screen authenticates against PAM service "login"
        # (Lockscreen.qml: `property string pamConfig: "login"`,
        # Quickshell.Services.Pam). With autologin no password is entered at
        # session start, so the keyring stays locked until the first screen
        # unlock — wire pam_gnome_keyring into that service so unlock opens
        # the login keyring too. Same wiring the noctalia branch proved
        # live (journals: `gkr-pam: unlocked login keyring` at lock-screen
        # unlocks); requires keyring and login passwords to match, true
        # since the 2026-09-23 keyring reset.
        security.pam.services.login.enableGnomeKeyring = true;

        # Runtime deps of the shell + its keybind set. System-level on
        # purpose: keybinds exec from Hyprland (uwsm session PATH) and the
        # lucid unit shells out constantly — /run/current-system/sw/bin
        # resolves for both. Python
        # env = lucidprefs/lucidshot helpers (gi for D-Bus, PIL + numpy +
        # fontTools for OCR/theme tooling); tesseract with deu+eng for
        # SUPER+SHIFT+T OCR. adw-gtk3: GTK live-retheming for matugen's
        # gtk3/gtk4 templates.
        environment.systemPackages = with pkgs; [
          adw-gtk3
          quickshell
          matugen
          awww # wallpaper daemon lucid's set-wallpaper.sh prefers (formerly swww)
          brightnessctl
          playerctl
          hyprpicker
          wtype
          grim
          slurp
          wf-recorder
          ffmpeg
          imagemagick
          hypridle
          jq
          libnotify
          glib # gdbus — Lockscreen.qml watches logind Lock/Unlock via `gdbus monitor`
          pulseaudio # pactl — lucid's Audio module probes sinks/sources with it
          (tesseract.override {
            enableLanguages = [
              "deu"
              "eng"
            ];
          })
          (python3.withPackages (
            p: with p; [
              pygobject3
              pillow
              numpy
              fonttools
            ]
          ))
        ];

        # Home-manager side: flip home/lucid.nix on (activation sync + user
        # services) and arm the lock-at-boot unit. Autologin boots into a
        # running session; lock it as soon as lucid can show its lock
        # screen.
        #
        # The After= below is load-bearing: a unit wanted by a target with no
        # ordering of its own gets an implicit After= FROM the target
        # (systemd.target default-dependencies complement Wants= with After=),
        # so the target waited for this oneshot's whole retry loop — which can
        # never succeed before lucid.service starts, itself After= the target.
        # Every autologin boot burned ~10s and the unit exited failed (lock
        # never engaged, 2026-09-25). A unit that orders itself after the
        # target is skipped by that complement (like lucid.service and
        # lucid-auto-mode.service), so the target starts it in parallel with
        # lucid.service; the retry loop catches the IPC handler once the QML
        # is up. Ordering it after lucid.service instead would cycle
        # (lucid -> target -> lock -> lucid) — the failure mode the old
        # "no-After" comment feared, just from the other direction.
        home-manager.users.${mainUser} = {
          desktop.lucid.enable = lib.mkDefault true;

          systemd.user.services.lucid-lock-at-boot = {
            Unit = {
              Description = "Lock the session after greetd autologin (auth moves to the lucid lock screen)";
              After = [ "graphical-session.target" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${lucidLockAtBoot}";
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
        };
      })
    ]
  );
}
