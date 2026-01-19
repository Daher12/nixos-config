{
  config,
  lib,
  flakeRoot,
  ...
}:

let
  cfg = config.features.sops;
  hostname = config.networking.hostName;
  secretsFile = flakeRoot + "/secrets/hosts/${hostname}.yaml";
  sshHostKey = "/etc/ssh/ssh_host_ed25519_key";
in
{
  options.features.sops = {
    enable = lib.mkEnableOption "SOPS Secret Management";

    method = lib.mkOption {
      type = lib.types.enum [ "age" "ssh" ];
      default = "age";
      description = "Decryption method: 'age' uses an age key file, 'ssh' derives an age identity from an SSH private key (typically the host ed25519 key).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      [
        {
          assertion = builtins.pathExists secretsFile;
          message = "SOPS enabled for host '${hostname}' but no secrets file found at: ${toString secretsFile}";
        }
      ]
      ++ lib.optional (cfg.method == "ssh") {
        assertion = builtins.pathExists sshHostKey;
        message = "SOPS method 'ssh' selected but SSH host key not found at: ${sshHostKey}";
      };

    sops = {
      defaultSopsFormat = "yaml";
      defaultSopsFile = secretsFile;

      # keyFile is nullOr path in sops-nix, so this is safe.
      age.keyFile = if cfg.method == "age" then "/var/lib/sops-nix/key.txt" else null;

      # Optional: you can omit this because sshKeyPaths already defaults to ed25519 hostKeys.
      # Keeping it makes the behavior explicit and independent of services.openssh.hostKeys.
      age.sshKeyPaths = lib.mkIf (cfg.method == "ssh") [ sshHostKey ];
    };
  };
}

