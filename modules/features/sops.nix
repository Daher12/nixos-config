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
    ];
    sops = {
      defaultSopsFormat = "yaml";
      defaultSopsFile = secretsPath;
      
      # Direct paths: bypass impermanence bind mount timing
      age = lib.mkIf (cfg.method == "age") {
        keyFile = "/persist/system/var/lib/sops-nix/key.txt";
      };
      
      age.sshKeyPaths = lib.mkIf (cfg.method == "ssh") [
        "/persist/system/etc/ssh/ssh_host_ed25519_key"
      ];
    };

    environment.systemPackages = [
      pkgs.sops
    ]
    # Maintenance: Only install ssh-to-age when actually needed for key derivation
    ++ lib.optional (cfg.method == "ssh") pkgs.ssh-to-age;
  };
}
