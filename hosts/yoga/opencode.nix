# Host-specific opencode bits. Shared settings (model/provider/permission/MCP,
# libstdc++ wrap) live in home/opencode.nix; this file opts in and persists
# opencode state across impermanence root wipes.
_: # No arguments used in this module
{
  opencode.enable = true;

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
}
