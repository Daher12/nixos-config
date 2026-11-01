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

    # MikroTik MCP (mikromcp): toggles only the opencode entry below — the
    # binary itself is always in home.packages so configs outside this module
    # (ZCode workspaces, RouterOS opencode.jsonc) can call it by bare name.
    custom.mikrotikMcp.enable = lib.mkEnableOption "MikroTik MCP server (mikromcp)";

    # windows-mcp: remote SSE server running INSIDE the windows11 VM
    # (libvirt NAT, 192.168.122.139). Only meaningful where that VM exists;
    # the server must be started in the guest and dies with the VM.
    custom.windowsMcp.enable = lib.mkEnableOption "Windows 11 VM MCP server (remote SSE)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.mcp-nixos
      # Unconditional (not behind mikrotikMcp): MCP configs outside opencode
      # reference "mikromcp" by name — hardcoded /nix/store paths rot on GC
      # (the 1.10.0 path in the RouterOS project already did).
      pkgs.mikromcp
    ];

    # Portable document skills (docx/pdf/pptx/xlsx) for opencode's skill tool
    # (~/.config/opencode/skills/<name>/SKILL.md). Sourced from the ZCode
    # plugin cache (documents 0.2.1 / pdf 0.2.2, 2026-11-01) with the
    # ZCode-only file-citation sections replaced by plain path reporting —
    # see docs/opencode-migration.md. ZCode-bound skills (browser-use,
    # computer-use, *-viewer, …) are intentionally not ported.
    xdg.configFile = builtins.listToAttrs (
      map
        (name: {
          name = "opencode/skills/${name}";
          value = {
            source = ./opencode-skills + "/${name}";
            recursive = true;
          };
        })
        [
          "docx"
          "pdf"
          "pptx"
          "xlsx"
        ]
    );

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
      package = inputs.opencode.packages.${pkgs.system}.default.overrideAttrs (previousAttrs: {
        postFixup = (previousAttrs.postFixup or "") + ''
          wrapProgram $out/bin/opencode \
            --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
        '';
      });
      settings = {
        # OpenRouter is the post-coding-plan baseline: both mains (deepseek
        # flash + glm flash) live there under one key (auth.json). The
        # zai-coding-plan provider below stays pickable while the plan lives
        # and turns into a harmless dead entry when it ends — no edits needed
        # on that day.
        model = "openrouter/deepseek/deepseek-v4-flash";
        small_model = "openrouter/deepseek/deepseek-v4-flash";
        agent = {
          build = {
            model = "openrouter/deepseek/deepseek-v4-flash";
            variant = "high";
          };
          plan = {
            model = "openrouter/z-ai/glm-5.3-flash";
            variant = "high";
          };
        };
        provider = {
          # reasoningEffort on the model (not an agent variant): opencode skips
          # variants for small-model calls (title generation etc.), so the
          # default effort must live here. Agent variants still override it.
          # GLM has no "off" effort — low is the minimum.
          "zai-coding-plan".models = {
            "glm-5.3-flash".options.reasoningEffort = "low";
            # Full-power model on the same plan (ZCode's main pick): kept
            # selectable for hard tasks; high matches the default variant
            # there. Flash above stays the cheap default.
            "glm-5.3".options.reasoningEffort = "high";
          };
          openrouter = {
            models = {
              # deepseek-v4-pro kept as the strong fallback pick; glm-5.3-flash
              # is the second main (agent.plan default).
              "deepseek/deepseek-v4-flash" = { };
              "z-ai/glm-5.3-flash" = { };
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
            # Curated from the ZCode bash allow-rulesets (2026-11-01 export of
            # ~480 accumulated approvals; frequency-ranked, see
            # docs/opencode-migration.md): read-only inspection plus the
            # house-standard build/eval/format gate commands. Deliberately
            # NOT auto-allowed: nix flake update, nix store gc/delete, sops,
            # nixos-rebuild beyond dry-build, and test-suite vm/full (those
            # keep the user confirmation gate from AGENTS.md QC).
            "git status *" = "allow";
            "git log *" = "allow";
            "git show *" = "allow";
            "git add *" = "allow";
            "journalctl *" = "allow";
            "nix eval *" = "allow";
            "nix fmt *" = "allow";
            "nix build *" = "allow";
            "nix path-info *" = "allow";
            "nix flake check" = "allow";
            "nix flake check *" = "allow";
            "nix flake show *" = "allow";
            "nix flake metadata *" = "allow";
            "nixos-rebuild dry-build *" = "allow";
            "nixos-rebuild list-generations" = "allow";
            "readlink *" = "allow";
            "realpath *" = "allow";
            "diff *" = "allow";
            "systemctl status *" = "allow";
            "systemctl cat *" = "allow";
            "virsh list *" = "allow";
            "virsh dominfo *" = "allow";
            "virsh dumpxml *" = "allow";
            "scripts/test-suite fast*" = "allow";
            "scripts/test-suite suggest" = "allow";
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
        }
        // lib.optionalAttrs config.custom.windowsMcp.enable {
          windows-mcp = {
            type = "remote";
            # windows11 VM on the libvirt NAT bridge; server runs in the
            # guest (`windows-mcp serve --transport sse --host 0.0.0.0
            # --port 8000 --allow-insecure-remote`) and dies with the VM.
            url = "http://192.168.122.139:8000/sse";
            # opencode v2 connects to every non-disabled remote server at
            # startup, so a shut-off VM meant a connect-error banner on
            # every launch. v2 has no conditional loading (the old command
            # form of `enabled` is gone; booleans only), so ship the entry
            # disabled and connect on demand while the VM runs:
            # `/mcp` -> select windows-mcp -> Enter.
            enabled = false;
          };
        };
      };
    };
  };
}
