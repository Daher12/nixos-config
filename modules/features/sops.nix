{ config, lib, flakeRoot, ... }:

let
  cfg = config.features.sops;
  hostname = config.networking.hostName;
  secretsFile = flakeRoot + "/secrets/hosts/${hostname}.yaml";
in
{
  options.features.sops = {
    enable = lib.mkEnableOption "SOPS Secret Management";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.pathExists secretsFile;
        message = "SOPS enabled for host '${hostname}' but no secrets file found at: ${toString secretsFile}";
      }
    ];

    sops = {
      defaultSopsFormat = "yaml";
      defaultSopsFile = secretsFile;
      age.keyFile = "/var/lib/sops-nix/key.txt";
    };
  };
}
