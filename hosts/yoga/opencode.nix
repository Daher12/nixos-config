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
      context = ../../AGENTS-global.md;
      package = inputs.opencode.packages.x86_64-linux.default.overrideAttrs (previousAttrs: {
        postFixup = (previousAttrs.postFixup or "") + ''
          wrapProgram $out/bin/opencode \
            --set LD_LIBRARY_PATH "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
        '';
      });
      settings = {
        model = "zai-coding-plan/glm-5.3-flash";
        small_model = "zai-coding-plan/glm-5.3-flash";
        agent = {
          build = {
            model = "zai-coding-plan/glm-5.3-flash";
            variant = "high";
          };
          plan = {
            model = "zai-coding-plan/glm-5.3";
            variant = "high";
          };
        };
        provider = {
          # reasoningEffort on the model (not an agent variant): opencode skips
          # variants for small-model calls (title generation etc.), so the
          # default effort must live here. Agent variants still override it.
          # GLM has no "off" effort — low is the minimum.
          "zai-coding-plan".models."glm-5.3-flash".options = {
            reasoningEffort = "low";
          };
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
          # orcarouter provider removed 2026-09-09 along with its
          # orcarouter_api_key sops secret (recoverable from git history).
        };
        permission = {
          edit = "ask";
          read = {
            "*" = "allow";
            "*.env" = "deny";
            "*.env.*" = "deny";
            "*.env.example" = "allow";
          };
          external_directory = "allow";
          bash = {
            "*" = "ask";
            "git status" = "allow";
            "git diff *" = "allow";
            "rm -rf *" = "deny";
            "ls *" = "allow";
            "cat *" = "allow";
            "rg *" = "allow";
            "grep *" = "allow";
            "find *" = "allow";
            "fd *" = "allow";
            "tree *" = "allow";
            "head *" = "allow";
            "tail *" = "allow";
            "wc *" = "allow";
            "stat *" = "allow";
            "file *" = "allow";
            "du *" = "allow";
            "which *" = "allow";
            "jq *" = "allow";
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
            # Toggle via `custom.mikrotikMcp.enable` in `hosts/yoga/default.nix`.
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
