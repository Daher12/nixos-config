{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.features.sops;
  hostname = config.networking.hostName;
  secretsPath = ../../secrets/hosts/${hostname}.yaml;

  useImpermanence = config.features.impermanence.enable or false;

  keyPath =
    if useImpermanence
    then "/persist/system/var/lib/sops-nix/key.txt"
    else "/var/lib/sops-nix/key.txt";

  sshKeyPath =
    if useImpermanence
    then "/persist/system/etc/ssh/ssh_host_ed25519_key"
    else "/etc/ssh/ssh_host_ed25519_key";
in
{
  options.features.sops = {
    enable = lib.mkEnableOption "SOPS Secret Management";
    method = lib.mkOption {
      type = lib.types.enum [ "age" "ssh" ];
      default = "age";
      description = "Decryption method: 'age' uses a static key file, 'ssh' derives it from host keys";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
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

      # Single age block with conditional attributes
      age = {
        keyFile = lib.mkIf (cfg.method == "age") keyPath;
        sshKeyPaths = lib.mkIf (cfg.method == "ssh") [ sshKeyPath ];
      };
    };

    environment.systemPackages = [ pkgs.sops ]
      ++ lib.optional (cfg.method == "ssh") pkgs.ssh-to-age;
  };
}
