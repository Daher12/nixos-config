# SOPS-nix secret management — per-host identity, one encrypted file per host.
#
# Architecture (details + operator runbook: SOPS_RUNBOOK.md at repo root):
#   * Every secrets/hosts/<host>.yaml is encrypted to the operator key
#     (admin_david, private key on yoga at ~/.config/sops/age/keys.txt) PLUS
#     the host's own identity — so files are editable from yoga as user dk and
#     decryptable by the device at activation.
#   * method = "ssh": the device identity is DERIVED from its persisted
#     /etc/ssh/ssh_host_ed25519_key (recipient = ssh-to-age of the .pub).
#     Nothing to provision; survives impermanence wipes and reinstalls.
#     Used by yoga. Requires the SSH host key to be persisted
#     (environment.persistence files, hosts/yoga/default.nix).
#   * method = "age": classic static key file at /var/lib/sops-nix/key.txt
#     (under /persist/system on impermanence hosts). Used by latitude and
#     nix-media; provisioning steps in the runbook.
#
# NOTE: modules/core/users.nix consumes "${mainUser}_password_hash" on every
# sops-enabled host — never delete that key from a per-host secrets file.
#
# Editing a file on yoga (as dk):  nix shell nixpkgs#sops -c sops secrets/hosts/<host>.yaml
# Re-encrypt after rule/key changes:  nix shell nixpkgs#sops -c sops updatekeys secrets/hosts/<host>.yaml
# Inspect recipients of a file:  nix shell nixpkgs#yq-go -c yq '.sops.age[].recipient' <file>
{
  config,
  flakeRoot,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.sops;
  hostname = config.networking.hostName;
  secretsPath = "${flakeRoot}/secrets/hosts/${hostname}.yaml";

  # Bypass impermanence bind-mount lifecycle: point directly to persist volume.
  # Guarantees key availability during early boot and nixos-install chroot (no systemd).
  persistPrefix = lib.optionalString (config.features.impermanence.enable or false) "/persist/system";
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
        assertion = hostname != "";
        message = "features.sops enabled but networking.hostName is empty; cannot resolve per-host secrets file path.";
      }
    ];

    sops = {
      defaultSopsFormat = "yaml";
      defaultSopsFile = secretsPath;

      # Type-stable: only define keys for the active method (avoids relying on nullOr).
      age = lib.mkMerge [
        (lib.mkIf (cfg.method == "age") {
          keyFile = "${persistPrefix}/var/lib/sops-nix/key.txt";
          # PATCH: clear upstream sshKeyPaths default to prevent unintended combined-identity
          # loading. sops-install-secrets merges all sources into one generated key file;
          # leaving sshKeyPaths active in age mode loads an extra unintended identity.
          sshKeyPaths = lib.mkForce [ ];
        })
        (lib.mkIf (cfg.method == "ssh") {
          # PATCH: mkForce replaces upstream default rather than appending to it.
          sshKeyPaths = lib.mkForce [ "${persistPrefix}/etc/ssh/ssh_host_ed25519_key" ];
        })
      ];
    };

    environment.systemPackages = [
      pkgs.sops
    ]
    # Maintenance: Only install ssh-to-age when actually needed for key derivation
    ++ lib.optional (cfg.method == "ssh") pkgs.ssh-to-age;
  };
}
