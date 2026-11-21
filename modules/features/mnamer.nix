{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.mnamer;

  inherit (cfg)
    batch
    recurse
    lower
    scene
    verbose
    language
    ignore
    mask
    replaceBefore
    replaceAfter
    extraSettings
    extraCliArgs
    ;

  inherit (cfg.paths)
    downloads
    movies
    shows
    kinderMovies
    kinderShows
    ;

  inherit (cfg.formats)
    movie
    episode
    ;

  resolvedPackage =
    if cfg.package != null then
      cfg.package
    else
      let
        rootPkg = lib.attrByPath [ "mnamer" ] null pkgs;
      in
      if rootPkg != null then rootPkg else lib.attrByPath [ "python3Packages" "mnamer" ] null pkgs;

  json = pkgs.formats.json { };

  # One generator, two configs. Per-lane differences: the destination pair,
  # the episode metadata provider (kids lane = TVDb, which honors
  # language=de — TvMaze, the main lane's provider, sends no language and
  # is not localized), and a lane-specific ignore entry: the MAIN config
  # excludes the kinder subtree (mnamer matches ignore regexes against the
  # full absolute path), so a main-lane import can never pull kids titles
  # into movies/shows even when the kinder import is declined or only
  # partially matched. The kinder config must not carry the exclusion.
  mkSettings =
    {
      movieDirectory,
      episodeDirectory,
      episodeApi,
      laneIgnore,
    }:
    json.generate "mnamer.json" (
      {
        inherit
          batch
          recurse
          lower
          scene
          verbose
          language
          mask
          ;

        # RHS `ignore` is the let-bound option value (attrset is not rec).
        ignore = ignore ++ cfg.extraIgnore ++ laneIgnore;

        no_overwrite = cfg.noOverwrite;
        no_guess = cfg.noGuess;

        episode_api = episodeApi;

        movie_directory = movieDirectory;
        episode_directory = episodeDirectory;

        movie_format = movie;
        episode_format = episode;

        replace_before = replaceBefore;
        replace_after = replaceAfter;
      }
      # Merge INSIDE json.generate: onto the settings attrset, not onto the
      # returned derivation. The old `generate … { … } // extraSettings`
      # parsed as `(generate … { … }) // extraSettings` — it still coerced
      # to the same store path, so it eval'd fine while extraSettings
      # silently never reached the file content.
      // extraSettings
    );

  settingsFile = mkSettings {
    movieDirectory = movies;
    episodeDirectory = shows;
    inherit (cfg) episodeApi;
    laneIgnore = [
      # Kinder sub-lane exclusion for the main config (see mkSettings).
      ".*/kinder/.*"
    ];
  };

  kinderSettingsFile = mkSettings {
    movieDirectory = kinderMovies;
    episodeDirectory = kinderShows;
    episodeApi = cfg.kinderEpisodeApi;
    laneIgnore = [ ];
  };

  commonArgs = [
    "--config-path"
    settingsFile
  ]
  ++ extraCliArgs;

  kinderArgs = [
    "--config-path"
    kinderSettingsFile
  ]
  ++ extraCliArgs;

  mnamerTools = pkgs.writeShellApplication {
    name = "mnamer-tools";
    runtimeInputs = [
      resolvedPackage
      pkgs.coreutils
    ];
    text = ''
            set -euo pipefail

            downloads=${lib.escapeShellArg downloads}

            run() {
              exec ${lib.getExe resolvedPackage} ${lib.escapeShellArgs commonArgs} "$@"
            }

            runKinder() {
              exec ${lib.getExe resolvedPackage} ${lib.escapeShellArgs kinderArgs} "$@"
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

              kinder-import-test)
                shift
                runKinder --test "$downloads/kinder" "$@"
                ;;

              kinder-import)
                shift
                runKinder "$downloads/kinder" "$@"
                ;;

              kinder-import-safe)
                shift
                runKinder --no-guess "$downloads/kinder" "$@"
                ;;

              kinder-source)
                printf '%s\n' "$downloads/kinder"
                ;;

              kinder-path)
                printf '%s\n' ${lib.escapeShellArg kinderSettingsFile}
                ;;

              kinder-dump)
                exec cat ${lib.escapeShellArg kinderSettingsFile}
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

              source)
                printf '%s\n' "$downloads"
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
        mnamer-tools <verb> [extra mnamer args...]

        Import verbs are safe by default (no_guess=true in both generated
        configs): files without a metadata hit are skipped in place, never
        renamed from parsed filenames. The *-safe verbs remain as explicit
        aliases.

        mnamer-tools import-test
        mnamer-tools movies-test
        mnamer-tools shows-test
        mnamer-tools import
        mnamer-tools import-safe
        mnamer-tools movies-safe
        mnamer-tools shows-safe
        mnamer-tools kinder-import-test
        mnamer-tools kinder-import
        mnamer-tools kinder-import-safe
        mnamer-tools kinder-source
        mnamer-tools raw ...
        mnamer-tools source
        mnamer-tools path
        mnamer-tools dump
        mnamer-tools kinder-path
        mnamer-tools kinder-dump
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

    # Safe by default (2026-11-21): mnamer's batch mode FALLS BACK to
    # filename-parsed metadata when a lookup returns zero hits — with
    # no_guess=false that moved unmatched files into the libraries under
    # guessed names (the junk-folder incident). true skips them in place
    # instead; media-import reports them as leftovers for hand-sorting.
    noGuess = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Skip files without metadata hits instead of renaming them from parsed filenames.";
    };

    # Episode providers: TvMaze (mnamer's default) sends no language
    # parameter and is not localized — its catalog is English-primary, so
    # German-named kids releases ("Feuerwehrmann.Sam…") find zero hits.
    # TVDb honors language=de in search and mnamer ships a bundled key, so
    # the kinder lane localizes for free. The main lane stays on TvMaze so
    # future episodes keep matching the existing (English-named) series
    # directories — flipping it would fork the on-disk library names.
    episodeApi = lib.mkOption {
      type = lib.types.enum [
        "tvdb"
        "tvmaze"
      ];
      default = "tvmaze";
      description = "Episode metadata provider for the main lane (config key episode_api).";
    };

    kinderEpisodeApi = lib.mkOption {
      type = lib.types.enum [
        "tvdb"
        "tvmaze"
      ];
      default = "tvdb";
      description = "Episode metadata provider for the kinder lane — TVDb honors language=de; TvMaze cannot match German kids releases.";
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

      kinderMovies = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/storage/kinder/filme";
        description = "Destination kids movie library path (kinder sub-lane).";
      };

      kinderShows = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/storage/kinder/serien";
        description = "Destination kids show library path (kinder sub-lane).";
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
        # mnamer re.searches these against the FULL absolute path
        # (re.IGNORECASE). The former "^RARBG.*" could never match (paths
        # start with "/"); segment-anchor instead of plain substring so
        # scene releases merely SUFFIXED with -RARBG still import —
        # only RARBG-prefixed junk (RARBG.txt & co) is skipped.
        "(^|/)RARBG.*"
        ".*\\.part[0-9]+.*"
        ".*\\btrailer\\b.*"
      ];
      description = "Regex patterns to ignore (matched against full paths).";
    };

    extraIgnore = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional ignore regexes appended to `ignore` in the generated config.";
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
        # "&" = "and" removed 2026-11-17: canonical titles keep the "&"
        # (mnamer language=de writes the TMDB title verbatim, and silo's
        # matcher doesn't normalize and→& — scene-style "and" names were
        # exactly the batch that failed auto-matching). "&" is
        # filesystem/NFS-safe.
        "@" = "at";
        ";" = ",";
      };
      description = "Replacement mapping applied after formatting.";
    };

    # No apiKeys.* options on purpose: any key value would be serialized
    # into settingsFile — a world-readable /nix/store path — violating the
    # repo's sops-only secrets rule. If keys are ever needed, render the
    # config from a sops secret instead (see features.litellm configFile).
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
        assertion = downloads != movies && downloads != shows;
        message = "features.mnamer: downloads path must be separate from movies/shows destinations.";
      }
      {
        assertion = movies != shows;
        message = "features.mnamer: movie and show destination paths must differ.";
      }
      {
        assertion = downloads != kinderMovies && downloads != kinderShows && kinderMovies != kinderShows;
        message = "features.mnamer: downloads and the kinder destinations must all differ.";
      }
    ];

    # mkIf gate: without it a null resolvedPackage crashes eval on list
    # coercion before the friendly assertion above can fire.
    environment.systemPackages = lib.mkIf (resolvedPackage != null) [
      resolvedPackage
      mnamerTools
    ];
  };
}
