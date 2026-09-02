{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  options.custom.mikrotikMcp.enable = lib.mkEnableOption "MikroTik MCP server (mikromcp)";

  config = {
    home.persistence."/persist".directories = [
      {
        directory = ".local/share/opencode";
        mode = "0700";
      }
      {
        directory = ".local/state/opencode";
        mode = "0700";
      }
      {
        directory = ".cache/opencode";
        mode = "0700";
      }
      {
        directory = ".config/opencode";
        mode = "0700";
      }
      {
        directory = ".mikromcp";
        mode = "0700";
      }
    ];

    home.packages = [
      pkgs.mcp-nixos
    ];

    # NOTE: opencode-cache-clean service REMOVED — was deleting node_modules
    # on boot, potentially breaking provider initialization. OpenCode manages
    # its own cache; deleting it forces re-download which can fail or race.

    programs.opencode = {
      enable = true;
      package = inputs.opencode.packages.x86_64-linux.default.overrideAttrs (previousAttrs: {
        postFixup = (previousAttrs.postFixup or "") + ''
          wrapProgram $out/bin/opencode \
            --set LD_LIBRARY_PATH "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
        '';
      });
      settings = {
        model = "openrouter/deepseek/deepseek-v4-flash";
        small_model = "openrouter/mistralai/mistral-small-3.2-24b-instruct";
        provider = {
          openrouter = {
            models = {
              "deepseek/deepseek-v4-flash" = { };
              "deepseek/deepseek-v4-pro" = {
                options = {
                  provider = {
                    order = [ "deepseek" ];
                    allow_fallbacks = true;
                  };
                };
              };
            };
          };
          orcarouter = {
            npm = "@ai-sdk/openai-compatible";
            name = "OrcaRouter";
            options = {
              baseURL = "https://api.orcarouter.ai/v1";
              apiKey = "{env:ORCAROUTER_API_KEY}";
            };
            models = {
              "orcarouter/auto" = {
                name = "OrcaRouter Auto";
              };
            };
          };
        };
        permission = {
          edit = "ask";
          bash = {
            "*" = "ask";
            "git status" = "allow";
            "git diff *" = "allow";
            "rm -rf *" = "deny";
          };
        };
        mcp = {
          nixos = {
            type = "local";
            command = [ "mcp-nixos" ];
          };
        }
        // lib.optionalAttrs config.custom.mikrotikMcp.enable {
          mikrotik = {
            type = "local";
            # Fixed nix package (pkgs/mikromcp.nix) — no npx/network at runtime.
            # Toggle via `hosts/yoga/default.nix:25` (custom.mikrotikMcp.enable).
            command = [
              "${lib.getExe pkgs.mikromcp}"
              "serve"
            ];
          };
        };
      };
    };
  };
}
