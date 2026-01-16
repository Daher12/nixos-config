{ inputs, config, lib, flakeRoot, ... }:

let
  cfg = config.features.sops;
  hostname = config.networking.hostName;
  # Use the passed-in flakeRoot (guaranteed to be a Store Path)
  secretsFile = flakeRoot + "/secrets/hosts/${hostname}.yaml";
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.features.sops = {
    enable = lib.mkEnableOption "SOPS Secret Management";
  };

  config = lib.mkIf cfg.enable {
    # Fail fast if the secrets file is missing from the flake source
    assertions = [
      {
        assertion = builtins.pathExists secretsFile;
        message = "SOPS enabled for host '${hostname}' but no secrets file found at: ${toString secretsFile}";
      }
    ];

    sops = {
      defaultSopsFormat = "yaml";
      defaultSopsFile = secretsFile;

      # Persistent key storage on the target host
      # Use a string here because it refers to a path on the DEPLOYED system, not the build host.
      age.keyFile = "/var/lib/sops-nix/key.txt";
    };
  };
}
