{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.sops;
  hostname = config.networking.hostName;
  secretsPath = ../../secrets/hosts/${hostname}.yaml;
in
{
  options.features.sops = {
    enable = lib.mkEnableOption "SOPS Secret Management";
    keyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sops-nix/key.txt";
      description = "Physical path to the SOPS age key (override to bypass stage-2 bind mounts)";
    };
    sshKeyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/etc/ssh/ssh_host_ed25519_key" ];
      description = "Physical paths to SSH keys for SOPS decryption (override to bypass stage-2 bind mounts)";
    };
    method = lib.mkOption {
      type = lib.types.enum [
        "age"
        "ssh"
      ];
      default = "age";
      description = "Decryption method: 'age' uses a static key file, 'ssh' derives it from host keys";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        # Avoid generating secrets/hosts/.yaml if hostName was forgotten in host glue.
        assertion = hostname != "";
        message = "features.sops enabled but networking.hostName is empty; cannot resolve per-host secrets file path.";
      }
      {
        assertion = builtins.pathExists secretsPath;
        message = "SOPS enabled for host '${hostname}' but no secrets file found at: secrets/hosts/${hostname}.yaml";
      }
      {
        assertion = cfg.method != "age" || lib.hasPrefix "/" cfg.keyFile;
        message = "features.sops.keyFile must be an absolute path (e.g., /persist/system/var/lib/sops-nix/key.txt) when method='age' to satisfy systemd.tmpfiles.";
      }
    ];

    sops = {
      defaultSopsFormat = "yaml";
      defaultSopsFile = secretsPath;
      # lib.mkMerge at attribute-set level cleanly excludes the inactive method's path definition,
      # preventing sops-nix from falling back to its internal defaults.
      age = lib.mkMerge [
        (lib.mkIf (cfg.method == "age") {
          keyFile = cfg.keyFile;
        })
        (lib.mkIf (cfg.method == "ssh") {
          sshKeyPaths = cfg.sshKeyPaths;
        })
      ];
    };

    # Maintenance: Only install ssh-to-age when actually needed for key derivation
    environment.systemPackages =
      [ pkgs.sops ]
      ++ lib.optional (cfg.method == "ssh") pkgs.ssh-to-age;

    # Declaratively enforce strict permissions on both physical and runtime paths against drift (stage-2 sysinit)
    systemd.tmpfiles.rules = lib.mkIf (cfg.method == "age") [
      "z ${cfg.keyFile} 0400 root root - -"
      "z /var/lib/sops-nix/key.txt 0400 root root - -"
    ];
  };
}
