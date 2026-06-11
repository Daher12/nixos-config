{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  gtk3,
  hicolor-icon-theme,
  roundedIcons ? false,
  blackPanelIcons ? false,
  allColorVariants ? false,
  colorVariants ? [ ],
}:
let
  pname = "Fluent-icon-theme";
in
lib.checkListOfEnum "${pname}: available color variants"
  [
    "standard"
    "green"
    "grey"
    "orange"
    "pink"
    "purple"
    "red"
    "yellow"
    "teal"
  ]
  colorVariants

  stdenvNoCC.mkDerivation
  rec {
    inherit pname;
    version = "unstable-2025-11-07";

    src = fetchFromGitHub {
      owner = "vinceliuice";
      repo = "Fluent-icon-theme";
      rev = "8a99a6d";
      hash = "sha256-5PStH2EmflLBL1AEylurkeaCfTvNejsf9DcThvD5SEo=";
    };

    nativeBuildInputs = [
      gtk3
    ];

    buildInputs = [ hicolor-icon-theme ];

    dontPatchELF = true;
    dontRewriteSymlinks = true;
    dontDropIconThemeCache = true;

    postPatch = ''
      patchShebangs install.sh
    '';

    installPhase = ''
      runHook preInstall

      ./install.sh --dest $out/share/icons \
        --name Fluent \
        ${toString colorVariants} \
        ${lib.optionalString allColorVariants "--all"} \
        ${lib.optionalString roundedIcons "--round"} \
        ${lib.optionalString blackPanelIcons "--black"}

      # Remove broken symlinks from upstream (icons linked to non-existent search.svg, etc.)
      find $out/share/icons -type l ! -exec test -e {} \; -delete

      runHook postInstall
    '';

    meta = {
      description = "Fluent icon theme for linux desktops (git main)";
      homepage = "https://github.com/vinceliuice/Fluent-icon-theme";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.linux;
      maintainers = with lib.maintainers; [ icy-thought ];
    };
  }
