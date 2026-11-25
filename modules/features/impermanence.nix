{
  inputs,
  config,
  lib,
  pkgs,
  utils,
  ...
}:

let
  cfg = config.features.impermanence;
  deviceUnit = "${utils.escapeSystemdPath cfg.device}.device";

  # Mirror impermanence's own view of every persisted file (system roots,
  # their `users` submodules, and home-manager users) so the heal snippet
  # below covers exactly the files `persist-files` will try to mount.
  impermanenceLib = pkgs.callPackage "${inputs.impermanence}/lib.nix" { };
  persistedFiles =
    let
      nixosRoots = lib.filter (v: v.enable) (lib.attrValues config.environment.persistence);
      nixosUsers = lib.flatten (map lib.attrValues (lib.catAttrs "users" nixosRoots));
      homeManager = lib.flatten (
        lib.mapAttrsToList (_: user: lib.attrValues (user.home.persistence or { })) (
          config.home-manager.users or { }
        )
      );
    in
    lib.flatten (map (v: v.files or [ ]) (nixosRoots ++ nixosUsers ++ homeManager));

  healLines = lib.unique (
    map (
      f:
      let
        mountPoint = f.filePath;
        targetFile = impermanenceLib.concatPaths [
          f.persistentStoragePath
          f.filePath
        ];
        backup = "/persist/heal-backups/" + builtins.replaceStrings [ "/" ] [ "_" ] targetFile + ".bak";
      in
      "persist_heal_file ${lib.escapeShellArg mountPoint} ${lib.escapeShellArg targetFile} ${lib.escapeShellArg backup}"
    ) persistedFiles
  );
in
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  options.features.impermanence = {
    enable = lib.mkEnableOption "Btrfs root rollback on boot";

    device = lib.mkOption {
      type = lib.types.nonEmptyStr;
      description = "Mapped LUKS block device, e.g. /dev/mapper/cryptroot";
      example = "/dev/mapper/cryptroot";
    };

    rootSubvolume = lib.mkOption {
      type = lib.types.str;
      default = "@";
      description = "Writable root subvolume mounted as /";
    };

    blankSubvolume = lib.mkOption {
      type = lib.types.str;
      default = "@blank";
      description = "Read-only template snapshot used to restore the root subvolume";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.fileSystems."/".fsType == "btrfs";
        message = "features.impermanence requires a Btrfs root filesystem.";
      }
      {
        assertion = lib.hasPrefix "/dev/mapper/" cfg.device;
        message = "features.impermanence: device must be a /dev/mapper/* path, got: ${cfg.device}";
      }
    ];

    # Heal stray plain files before impermanence's persist-files runs (both
    # at boot-time and switch-time activation). Writers that save atomically
    # (write temp file, rename over the final name: GTK recently-used.xbel,
    # mutter monitors.xml, xdg-user-dirs) replace impermanence's boot-time
    # symlink with a plain regular file whenever the /persist source does not
    # exist yet, and the next persist-files run then aborts on
    # "A file already exists at <path>!" (upstream issue #147). Migrate a
    # first stray into /persist so a real bind mount forms, or back up and
    # drop later ones — the automated form of the manual fix, so no switch
    # or boot ever fails on this class again.
    system.activationScripts.persist-files.text = lib.mkBefore ''
      persist_heal_file() {
        local mp="$1" tf="$2" bk="$3"
        # Only stray plain files: skip the expected symlink and live mounts.
        if [[ -f "$mp" && ! -L "$mp" ]] && ! findmnt "$mp" >/dev/null 2>&1; then
          if [[ ! -e "$tf" ]]; then
            echo "persist-heal: migrating $mp -> $tf"
            mkdir -p "$(dirname "$tf")"
            cp -p "$mp" "$tf"
            rm -f "$mp"
          else
            echo "persist-heal: $tf already persisted; backing up stray $mp"
            mkdir -p "$(dirname "$bk")"
            cp -p "$mp" "$bk"
            rm -f "$mp"
          fi
        fi
      }
      ${lib.concatStringsSep "\n" healLines}
    '';

    boot.initrd.systemd = {
      enable = true;

      storePaths = [
        "${pkgs.btrfs-progs}/bin/btrfs"
        "${pkgs.util-linux}/bin/mount"
        "${pkgs.util-linux}/bin/umount"
        "${pkgs.coreutils}/bin/chmod"
        # mkdir -p /btrfs in the rollback script. Present in the initrd via
        # the default coreutils initrdBin today; listed explicitly so a
        # nixpkgs default change can't break boot.
        "${pkgs.coreutils}/bin/mkdir"
      ];

      services = {
        # initrd-nixos-activation chroots into /sysroot and executes binaries
        # from /nix/store. With split subvolumes, /sysroot/nix and
        # /sysroot/persist must be mounted before activation starts.
        initrd-nixos-activation = {
          after = [ "sysroot.mount" ];
          unitConfig.RequiresMountsFor = [
            "/sysroot/nix/store"
            "/sysroot/persist"
          ];
        };

        rollback-root = {
          description = "Rollback Btrfs root subvolume from template snapshot";
          wantedBy = [ "initrd-root-device.target" ];
          before = [ "sysroot.mount" ];
          after = [
            deviceUnit
            # Never wipe the root subvolume before a hibernate image is
            # given a chance to restore: on a resume boot the kernel jumps
            # into the restored image inside systemd-hibernate-resume.service
            # and this initrd (hence the wipe) never finishes. Without this
            # ordering the two units race (journal 2026-09-06 shows them
            # interleaved) and a resumed session would write into a deleted
            # subvolume. On normal boots that unit fails fast ("Image not
            # found"), which does not block ordering; hosts whose initrd
            # lacks the unit treat this as a no-op.
            "systemd-hibernate-resume.service"
          ];
          requires = [ deviceUnit ];

          unitConfig = {
            DefaultDependencies = "no";
            OnFailure = "emergency.target";
          };

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };

          script = ''
            set -euo pipefail

            ROOT="${cfg.rootSubvolume}"
            BLANK="${cfg.blankSubvolume}"

            mkdir -p /btrfs
            mount -t btrfs -o subvolid=5 "${cfg.device}" /btrfs
            trap 'umount /btrfs 2>/dev/null || true' EXIT

            delete_subvolume_recursively() {
              local target="$1"
              local list
              list=$(btrfs subvolume list -o "$target") || {
                echo "ERROR: failed to list child subvolumes of $target" >&2
                exit 1
              }
              local line
              while IFS= read -r line; do
                [ -n "$line" ] || continue
                delete_subvolume_recursively "/btrfs/''${line##* }"
              done <<< "$list"
              echo "Deleting subvolume: $target" >&2
              btrfs subvolume delete "$target"
            }

            if ! btrfs subvolume show "/btrfs/$BLANK" >/dev/null 2>&1; then
              echo "ERROR: missing template snapshot /btrfs/$BLANK" >&2
              exit 1
            fi

            _ro=$(btrfs property get -ts "/btrfs/$BLANK" ro) || {
              echo "ERROR: failed to read ro property of /btrfs/$BLANK" >&2
              exit 1
            }
            if [ "$_ro" != "ro=true" ]; then
              echo "ERROR: /btrfs/$BLANK is not a read-only snapshot" >&2
              exit 1
            fi

            for d in \
              nix \
              persist \
              boot \
              home \
              etc \
              tmp \
              var \
              var/log \
              var/lib \
              var/lib/sops-nix \
              var/lib/sbctl
            do
              if [ ! -e "/btrfs/$BLANK/$d" ]; then
                echo "ERROR: template /btrfs/$BLANK is missing required path: /$d" >&2
                exit 1
              fi
            done

            if btrfs subvolume show "/btrfs/$ROOT" >/dev/null 2>&1; then
              delete_subvolume_recursively "/btrfs/$ROOT"
            elif [ -e "/btrfs/$ROOT" ]; then
              echo "ERROR: /btrfs/$ROOT exists but is not a Btrfs subvolume" >&2
              exit 1
            fi

            btrfs subvolume snapshot "/btrfs/$BLANK" "/btrfs/$ROOT"
            chmod 1777 "/btrfs/$ROOT/tmp"
          '';
        };
      };
    };
  };
}
