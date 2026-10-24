# Option-level sops-nix stub shared by the VM tests that import repo modules
# touching sops.secrets (hosts/nix-media/ntfy.nix, modules/core/users.nix,
# modules/features/sops.nix).
#
# The real sops-nix machinery is deliberately absent: these tests carry no
# decryption keys, so every secret's /run/secrets path stays missing at
# runtime — which is itself the production branch under test (ntfy-send's
# documented missing-secret skip). Only the option SHAPE is provided: a
# per-secret readOnly `path` (the one thing build-time consumers read) plus
# freeform absorption for the attributes the repo modules set.
{
  lib,
  ...
}:

{
  options.sops = {
    secrets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            freeformType = lib.types.anything;
            options.path = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
            };
            config.path = "/run/secrets/" + name;
          }
        )
      );
      default = { };
    };

    # Set by modules/features/sops.nix; accepted and ignored.
    defaultSopsFormat = lib.mkOption {
      type = lib.types.str;
      default = "yaml";
    };
    defaultSopsFile = lib.mkOption {
      type = lib.types.anything;
      default = null;
    };
    age = {
      keyFile = lib.mkOption {
        type = lib.types.anything;
        default = null;
      };
      sshKeyPaths = lib.mkOption {
        type = lib.types.anything;
        default = null;
      };
    };
  };
}
