# LiteLLM API gateway — local OpenAI-compatible proxy for coding assistants.
#
# Point IDE/agent tools at http://127.0.0.1:4001 instead of provider endpoints;
# provider routing changes stay inside the LiteLLM config. Disabled by default:
# enabling requires a real config file (model list + master key) that carries no
# secrets in this repo.
#
# Secret provisioning (sops-nix): sops renders secrets root:root 0400 by
# default, which a DynamicUser service cannot read. The config is therefore
# passed through systemd LoadCredential, which copies it readable-by-service
# into /run/credentials/. Operator steps:
#   1. add the YAML content as `litellm_config` to secrets/hosts/<host>.yaml
#   2. wire the secret, e.g. in the host module:
#        sops.secrets."litellm_config" = {
#          sopsFile = ...;  # or rely on features.sops defaults
#        };
#        features.litellm = {
#          enable = true;
#          configFile = config.sops.secrets."litellm_config".path;
#        };
#   3. switch. (A plain static path also works — that is what the VM test uses.)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.litellm;
in
{
  options.features.litellm = {
    enable = lib.mkEnableOption "LiteLLM API gateway (127.0.0.1 only)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 4001;
      description = "TCP port the gateway listens on (loopback only).";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/litellm_config";
      description = ''
        Path to the litellm config.yaml. Required when enable = true. Fed to
        the service via systemd LoadCredential (i.e. copied readable-by-service
        to /run/credentials/), so a sops-rendered root-owned 0400 file works
        despite DynamicUser.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.configFile != null;
        message = "features.litellm.enable requires features.litellm.configFile (sops-rendered or static).";
      }
    ];

    systemd.services.litellm = {
      description = "LiteLLM API gateway";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      # DynamicUser defaults HOME to "/" — litellm wants a writable home.
      environment = {
        HOME = "/var/lib/litellm";
      };

      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${lib.getExe pkgs.litellm}"
          "--config \${CREDENTIALS_DIRECTORY}/litellm-config"
          "--host 127.0.0.1"
          "--port ${toString cfg.port}"
        ];
        # systemd expands $CREDENTIALS_DIRECTORY itself; the source file may be
        # root:root 0400 (sops default) — LoadCredential bridges that.
        LoadCredential = [ "litellm-config:${cfg.configFile}" ];
        DynamicUser = true;
        StateDirectory = "litellm";
        # Harden: read-only root, private tmp, no privileges, loopback sockets.
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
