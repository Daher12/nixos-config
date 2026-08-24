{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  gtk-engine-murrine,
  jdupes,
  sassc,
  themeVariants ? [ ],
  colorVariants ? [ ],
  sizeVariants ? [ ],
  tweaks ? [ ],
}:

let
  pname = "colloid-gtk-theme";

in
lib.checkListOfEnum "colloid-gtk-theme: theme variants"
  [
    "default"
    "purple"
    "pink"
    "red"
    "orange"
    "yellow"
    "green"
    "teal"
    "grey"
    "all"
  ]
  themeVariants
  lib.checkListOfEnum
  "colloid-gtk-theme: color variants"
  [ "standard" "light" "dark" ]
  colorVariants
  lib.checkListOfEnum
  "colloid-gtk-theme: size variants"
  [ "standard" "compact" ]
  sizeVariants
  lib.checkListOfEnum
  "colloid-gtk-theme: tweaks"
  [
    "nord"
    "dracula"
    "gruvbox"
    "everforest"
    "catppuccin"
    "all"
    "black"
    "rimless"
    "normal"
    "float"
  ]
  tweaks

  stdenvNoCC.mkDerivation
  {
    inherit pname;
    version = "unstable-2026-08-17";

    src = fetchFromGitHub {
      owner = "vinceliuice";
      repo = "colloid-gtk-theme";
      rev = "6f000fc";
      hash = "sha256-dkYd1GVYL0VmiQAPx7XHQtDWym44O0kpqVYhgvvLDNg=";
    };

    nativeBuildInputs = [
      jdupes
      sassc
    ];

    propagatedUserEnvPkgs = [
      gtk-engine-murrine
    ];

    postPatch = ''
      patchShebangs install.sh
    '';

    installPhase = ''
      runHook preInstall

      name= HOME="$TMPDIR" ./install.sh \
        ${lib.optionalString (themeVariants != [ ]) "--theme " + toString themeVariants} \
        ${lib.optionalString (colorVariants != [ ]) "--color " + toString colorVariants} \
        ${lib.optionalString (sizeVariants != [ ]) "--size " + toString sizeVariants} \
        ${lib.optionalString (tweaks != [ ]) "--tweaks " + toString tweaks} \
        --libadwaita \
        --dest $out/share/themes

      jdupes --quiet --link-soft --recurse $out/share

      runHook postInstall
    '';

    meta = {
      description = "Modern and clean Gtk theme (git main for GNOME 50 support)";
      homepage = "https://github.com/vinceliuice/Colloid-gtk-theme";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.unix;
      maintainers = [ lib.maintainers.romildo ];
    };
  }
