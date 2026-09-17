# Shared opencode (AI coding agent) home-manager config. Opt in per host via
# `opencode.enable = true` in hosts/<name>/home.nix (like browsers.*).
# Host-specific bits live in the host files: yoga adds impermanence
# persistence entries (hosts/yoga/opencode.nix).
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.opencode;
in
{
  options = {
    opencode.enable = lib.mkEnableOption "opencode (shared settings)";

    # MikroTik MCP (mikromcp): separate toggle so a host can disable the MCP
    # server without touching the rest of the opencode config (yoga flips it
    # in hosts/yoga/default.nix; ~/.mikromcp data is persisted either way).
    custom.mikrotikMcp.enable = lib.mkEnableOption "MikroTik MCP server (mikromcp)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.mcp-nixos
    ];

    # NOTE: no opencode-cache-clean service — it previously deleted
    # node_modules on boot, potentially breaking provider initialization.
    # OpenCode manages its own cache; deleting it forces re-download which
    # can fail or race.

    programs.opencode = {
      enable = true;
      context = ../AGENTS-global.md;
      # Upstream binary links against a libstdc++ older than the one in
      # nixpkgs — wrap with the current one or it dies on
      # `libstdc++.so.6: version GLIBCXX not found` (REPO_OVERVIEW Known
      # Gotchas). NixOS-generic, applies to every host using this module.
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
            # Toggle via `custom.mikrotikMcp.enable` in the host config.
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
