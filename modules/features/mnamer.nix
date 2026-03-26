{ config, lib, pkgs, ... }:

let
  cfg = config.features.mnamer;

  resolvedPackage =
    if cfg.package != null then
      cfg.package
    else
      let
        rootPkg = lib.attrByPath [ "mnamer" ] null pkgs;
      in
      if rootPkg != null then
        rootPkg
      else
        lib.attrByPath [ "python3Packages" "mnamer" ] null pkgs;

  json = pkgs.formats.json { };

  settingsFile = json.generate "mnamer-v2.json" (
    {
      batch = cfg.batch;
      recurse = cfg.recurse;
      lower = cfg.lower;
      scene = cfg.scene;
      verbose = cfg.verbose;
      no_overwrite = cfg.noOverwrite;
      no_guess = cfg.noGuess;
      language = cfg.language;

      movie_directory = cfg.paths.movies;
      episode_directory = cfg.paths.shows;

      movie_format = cfg.formats.movie;
      episode_format = cfg.formats.episode;

      ignore = cfg.ignore;
      mask = cfg.mask;

      replace_before = cfg.replaceBefore;
      replace_after = cfg.replaceAfter;
    }
    // lib.optionalAttrs (cfg.apiKeys.tmdb != null) {
      api_key_tmdb = cfg.apiKeys.tmdb;
    }
    // lib.optionalAttrs (cfg.apiKeys.omdb != null) {
      api_key_omdb = cfg.apiKeys.omdb;
    }
    // lib.optionalAttrs (cfg.apiKeys.tvdb != null) {
      api_key_tvdb = cfg.apiKeys.tvdb;
    }
    // lib.optionalAttrs (cfg.apiKeys.tvmaze != null) {
      api_key_tvmaze = cfg.apiKeys.tvmaze;
    }
    // cfg.extraSettings
  );

  commonArgs =
    [
      "--config-path"
      settingsFile
    ]
    ++ cfg.extraCliArgs;

  mnamerTools = pkgs.writeShellApplication {
    name = "mnamer-tools";
    runtimeInputs = [ resolvedPackage ];
    text = ''
      set -euo pipefail

      downloads=${lib.escapeShellArg cfg.paths.downloads}

      run() {
        exec ${lib.getExe resolvedPackage} ${lib.escapeShellArgs commonArgs} "$@"
      }

      case "''${1-}" in
        import-test)
          shift
          run --test "$downloads" "$@"
          ;;

        movies-test)
          shift
          run --test --no-guess --media movie "$downloads" "$@"
          ;;

        shows-test)
          shift
          run --test --no-guess --media episode "$downloads" "$@"
          ;;

        import)
          shift
          run "$downloads" "$@"
          ;;

        import-safe)
          shift
          run --no-guess "$downloads" "$@"
          ;;

        movies-safe)
          shift
          run --no-guess --media movie "$downloads" "$@"
          ;;

        shows-safe)
          shift
          run --no-guess --media episode "$downloads" "$@"
          ;;

        raw)
          shift
          run "$@"
          ;;

        path)
          printf '%s\n' ${lib.escapeShellArg settingsFile}
          ;;

        dump)
          exec cat ${lib.escapeShellArg settingsFile}
          ;;

        *)
          cat <<'EOF'
Usage:
  mnamer-tools import-test
  mnamer-tools movies-test
  mnamer-tools shows-test
  mnamer-tools import
  mnamer-tools import-safe
  mnamer-tools movies-safe
  mnamer-tools shows-safe
  mnamer-tools raw ...
  mnamer-tools path
  mnamer-tools dump
EOF
          exit 1
          ;;
      esac
    '';
  };
in
{
  options.features.mnamer = {
    enable = lib.mkEnableOption "mnamer media organization tooling";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "mnamer package to use. If null, try pkgs.mnamer then pkgs.python3Packages.mnamer.";
    };

    batch = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run mnamer in batch mode.";
    };

    recurse = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Search recursively in the source directory.";
    };

    lower = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Lowercase generated names.";
    };

    scene = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use scene-style dot-separated naming.";
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable verbose mnamer output.";
    };

    noOverwrite = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Do not overwrite existing destination files.";
    };

    noGuess = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Default no-guess setting for generated config.";
    };

    language = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "de";
      example = "de";
      description = "Language used for metadata lookup and templating.";
    };

    paths = {
      downloads = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/storage/downloads";
        description = "Source directory containing unsorted media.";
      };

      movies = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/storage/movies";
        description = "Destination movie library path.";
      };

      shows = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/storage/shows";
        description = "Destination show library path.";
      };
    };

    formats = {
      movie = lib.mkOption {
        type = lib.types.str;
        default = "{name} ({year})/{name} ({year}).{extension}";
        description = "Movie destination path and filename format.";
      };

      episode = lib.mkOption {
        type = lib.types.str;
        default = "{series}/Season {season:02}/{series} - S{season:02}E{episode:02} - {title}.{extension}";
        description = "Episode destination path and filename format.";
      };
    };

    ignore = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        ".*sample.*"
        "^RARBG.*"
        ".*\\.part[0-9]+.*"
        ".*\\btrailer\\b.*"
      ];
      description = "Regex patterns to ignore.";
    };

    mask = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "mkv"
        "mp4"
        "m4v"
        "avi"
        "ts"
        "wmv"
        "srt"
        "ass"
        "ssa"
        "sub"
        "idx"
      ];
      description = "Allowed file extensions for processing.";
    };

    replaceBefore = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Replacement mapping applied before formatting.";
    };

    replaceAfter = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        "&" = "and";
        "@" = "at";
        ";" = ",";
      };
      description = "Replacement mapping applied after formatting.";
    };

    apiKeys = {
      tmdb = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "TMDb API key.";
      };

      omdb = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "OMDb API key.";
      };

      tvdb = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "TVDb API key.";
      };

      tvmaze = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "TvMaze API key.";
      };
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra raw mnamer JSON settings merged into the generated config.";
    };

    extraCliArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional CLI arguments passed by wrapper commands.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = resolvedPackage != null;
        message = "features.mnamer.enable is true, but no mnamer package was found. Set features.mnamer.package explicitly.";
      }
      {
        assertion =
          cfg.paths.downloads != cfg.paths.movies
          && cfg.paths.downloads != cfg.paths.shows;
        message = "features.mnamer: downloads path must be separate from movies/shows destinations.";
      }
      {
        assertion = cfg.paths.movies != cfg.paths.shows;
        message = "features.mnamer: movie and show destination paths must differ.";
      }
    ];

    environment.systemPackages = [
      resolvedPackage
      mnamerTools
    ];

    environment.etc."mnamer/config.json".source = settingsFile;
  };
}
