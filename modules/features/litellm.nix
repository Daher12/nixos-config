# LiteLLM API gateway — local OpenAI-compatible proxy for coding assistants.
#
# Point IDE/agent tools at http://127.0.0.1:4001 instead of provider endpoints;
# provider routing changes stay inside the LiteLLM config. Disabled by default:
# enabling requires a real config file (model list + master key) that carries no
# secrets in this repo. Recommended provisioning via sops-nix:
#   1. operator adds `litellm_config: <yaml content>` to secrets/hosts/<host>.yaml
#   2. host module sets services.litellm.configFile =
#        config.sops.secrets."litellm_config".path
#   3. set features.litellm.enable = true
# For tests a plain static path can be injected instead.
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
        Path to the litellm config.yaml. Required when enable = true; may point
        at a sops-rendered secret path so keys never live in the store.
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
          "--config ${cfg.configFile}"
          "--host 127.0.0.1"
          "--port ${toString cfg.port}"
        ];
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
