{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.core.boot;
  sbActive = config.features.secureboot.enable or false;
in
{
  options.core.boot = {
    silent = lib.mkEnableOption "silent boot with Plymouth";
    plymouth.theme = lib.mkOption {
      type = lib.types.enum [
        "bgrt"
        "spinner"
        "script"
        "text"
      ];
      default = "spinner";
      description = "Plymouth theme to use";
    };
    tmpfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount /tmp in RAM";
      };
      size = lib.mkOption {
        type = lib.types.str;
        description = "Size of tmpfs";
      };
    };
  };

  config = {
    boot = {
      consoleLogLevel = if cfg.silent then 0 else 3;
      initrd = {
        verbose = !cfg.silent;
        systemd = {
          enable = true;
          services."systemd-cryptsetup@".after = lib.mkIf cfg.silent [ "plymouth-start.service" ];
          # Exclude label-freetype.so / label-pango.so from the initrd.
          # These were added upstream (Fedora 42 / NixOS 26.05) to render a
          # device-name label below the LUKS prompt.  The bgrt/spinner themes
          # use two-step.so for the actual password entry widget, so removing
          # the label plugin has no effect on functionality.
          contents = lib.mkIf cfg.silent {
            "/etc/plymouth/plugins".source = lib.mkForce (
              let
                pluginSource = pkgs.buildEnv {
                  name = "plymouth-all-plugins";
                  paths = [ config.boot.plymouth.package ] ++ config.boot.plymouth.themePackages;
                };
              in
              pkgs.runCommand "plymouth-initrd-plugins-nolabel" { } ''
                mkdir -p $out/renderers
                for f in ${pluginSource}/lib/plymouth/*.so; do
                  [ -e "$f" ] || continue
                  name=$(basename "$f")
                  case "$name" in
                    label-*) ;;
                    *) cp "$f" "$out/" ;;
                  esac
                done
                for f in ${pluginSource}/lib/plymouth/renderers/*.so; do
                  [ -e "$f" ] || continue
                  name=$(basename "$f")
                  case "$name" in
                    x11.so) ;;
                    *) cp "$f" "$out/renderers/" ;;
                  esac
                done
              ''
            );
          };
        };
        compressor = "zstd";
        compressorArgs = [
          "-3"
          "-T0"
        ];
      };

      plymouth = lib.mkIf cfg.silent {
        enable = true;
        inherit (cfg.plymouth) theme;
      };
      kernelParams = lib.mkIf cfg.silent [
        "quiet"
        "splash"
        "plymouth.use-simpledrm"
        "vt.global_cursor_default=0"
        "systemd.show_status=false"
        "udev.log_level=3"
        "loglevel=3"
        "systemd.log_level=warning"
        "nowatchdog"
      ];
      loader = {
        timeout = lib.mkDefault 3;
        systemd-boot = {
          enable = lib.mkDefault (!sbActive);
          configurationLimit = lib.mkDefault 10;
          consoleMode = lib.mkDefault "keep";
        };
        efi.canTouchEfiVariables = true;
        efi.efiSysMountPoint = lib.mkDefault "/boot";
      };
      tmp = lib.mkIf cfg.tmpfs.enable {
        useTmpfs = true;
        tmpfsSize = cfg.tmpfs.size;
        cleanOnBoot = true;
      };
    };

    services.udev.extraRules = ''
      ACTION=="add|change", SUBSYSTEM=="block", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
    '';
  };
}
