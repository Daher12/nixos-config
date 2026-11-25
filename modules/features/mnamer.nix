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
      noGuess ? cfg.noGuess,
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
        no_guess = noGuess;

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

  # Guess-preview configs: identical to the lane configs except
  # no_guess=false, so mnamer's batch fallback (filename-parsed metadata
  # when a lookup returns zero hits) is active. The wrapper exposes these
  # ONLY behind --test verbs — guessing moves are what created the junk
  # library entries, so they stay preview-only: see what the guess would
  # name a file, never let it move one.
  guessSettingsFile = mkSettings {
    movieDirectory = movies;
    episodeDirectory = shows;
    inherit (cfg) episodeApi;
    laneIgnore = [
      ".*/kinder/.*"
    ];
    noGuess = false;
  };

  kinderGuessSettingsFile = mkSettings {
    movieDirectory = kinderMovies;
    episodeDirectory = kinderShows;
    episodeApi = cfg.kinderEpisodeApi;
    laneIgnore = [ ];
    noGuess = false;
  };

  # Review tool: readFile keeps the Python free of Nix-escaping (same
  # pattern as hosts/nix-media's zsh files). Parsed contract targets
  # mnamer 2.6.0 — see the script's header comment.
  reviewScript = pkgs.writeText "mnamer-review.py" (builtins.readFile ./mnamer-review.py);

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

  guessArgs = [
    "--config-path"
    guessSettingsFile
  ]
  ++ extraCliArgs;

  kinderGuessArgs = [
    "--config-path"
    kinderGuessSettingsFile
  ]
  ++ extraCliArgs;

  mnamerTools = pkgs.writeShellApplication {
    name = "mnamer-tools";
    runtimeInputs = [
      resolvedPackage
      pkgs.coreutils
      pkgs.python3
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

            # Preview-only (always --test): guess configs, see mkSettings.
            runGuess() {
              exec ${lib.getExe resolvedPackage} ${lib.escapeShellArgs guessArgs} "$@"
            }

            runKinderGuess() {
              exec ${lib.getExe resolvedPackage} ${lib.escapeShellArgs kinderGuessArgs} "$@"
            }

            case "''${1-}" in
              import-test)
                shift
                run --test "$downloads" "$@"
                ;;

              import-overview)
                shift
                exec python3 ${reviewScript} --mode import \
                  --mnamer ${lib.getExe resolvedPackage} \
                  --lane "main:${downloads}:${settingsFile}:${cfg.episodeApi}:${guessSettingsFile}" \
                  "$@"
                ;;

              kinder-import-overview)
                shift
                exec python3 ${reviewScript} --mode import \
                  --mnamer ${lib.getExe resolvedPackage} \
                  --lane "kinder:${downloads}/kinder:${kinderSettingsFile}:${cfg.kinderEpisodeApi}:${kinderGuessSettingsFile}" \
                  "$@"
                ;;

              import-guess-test)
                shift
                runGuess --test "$downloads" "$@"
                ;;

              kinder-import-guess-test)
                shift
                runKinderGuess --test "$downloads/kinder" "$@"
                ;;

              movies-test)
                shift
                run --test --media movie "$downloads" "$@"
                ;;

              shows-test)
                shift
                run --test --media episode "$downloads" "$@"
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

              kinder-source)
                printf '%s\n' "$downloads/kinder"
                ;;

              kinder-path)
                printf '%s\n' ${lib.escapeShellArg kinderSettingsFile}
                ;;

              kinder-dump)
                exec cat ${lib.escapeShellArg kinderSettingsFile}
                ;;

              review)
                shift
                exec python3 ${reviewScript} \
                  --mnamer ${lib.getExe resolvedPackage} \
                  --lane "main:${downloads}:${settingsFile}:${cfg.episodeApi}:${guessSettingsFile}" \
                  --lane "kinder:${downloads}/kinder:${kinderSettingsFile}:${cfg.kinderEpisodeApi}:${kinderGuessSettingsFile}" \
                  "$@"
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
        renamed from parsed filenames. The old *-safe verbs were removed —
        safety is no longer a variant.

        The *-guess-test verbs are DRY-ONLY previews with guessing enabled
        (no_guess=false config): they show what mnamer's filename-guess
        fallback would name unmatched files. There is deliberately no
        moving variant.

        mnamer-tools import-test
        mnamer-tools import-overview [--guess] [--ascii]  # boxed table + prompt
        mnamer-tools kinder-import-overview [--guess] [--ascii]
        mnamer-tools import-guess-test
        mnamer-tools kinder-import-guess-test
        mnamer-tools review [--no-suggest] [--ascii]  # table + suggestions + picks
        mnamer-tools movies-test
        mnamer-tools shows-test
        mnamer-tools import
        mnamer-tools kinder-import-test
        mnamer-tools kinder-import
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
    # German-named kids releases ("Feuerwehrmann.Sam…") find zero hits…
    # except via TvMaze's alias search, which catches some titles
    # ("Bob der Baumeister" → "Bob the Builder"). TVDb WAS the German
    # option (language=de search) but its v3 /search/series went 404
    # (~2026-11, probed live; v4 rejects mnamer's bundled key) — TvDb
    # search is dead in mnamer 2.6, so both lanes ride TvMaze for
    # auto-match and the German series residue flows to `mnamer-tools
    # review`, whose suggestions search TMDb-tv (language=de, alive) and
    # resolve ids for either provider.
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
      default = "tvmaze";
      description = "Episode metadata provider for the kinder lane — TvMaze (alias search, alive); TvDb search is dead upstream, German residue goes through review.";
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
