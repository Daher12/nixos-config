{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  jdupes,
  sassc,
  glib,
  libxml2,
  dialog,
  util-linux,
}:

stdenvNoCC.mkDerivation {
  pname = "mactahoe-gtk-theme";
  version = "0-unstable-2026-06-19";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "MacTahoe-gtk-theme";
    rev = "3267b3dfd9b6c3e775ad9b1f3079f848fc076bf6";
    sha256 = "1bg8i2i9drqalrxlc61mncvbygcs2illw6a7mxhfrjjlmr9d8x7x";
  };

  nativeBuildInputs = [
    dialog
    glib
    jdupes
    libxml2
    sassc
    util-linux
  ];

  postPatch = ''
    find -name "*.sh" -print0 | while IFS= read -r -d ''' file; do
      patchShebangs "$file"
    done

    substituteInPlace libs/lib-core.sh --replace-fail '$(which sudo)' false
    substituteInPlace libs/lib-core.sh --replace-fail 'MY_HOME=$(getent passwd "''${MY_USERNAME}" | cut -d: -f6)' 'MY_HOME=/tmp'
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/themes

    export SHELL_VERSION=48

    HOME="$TMPDIR" ./install.sh \
      --color dark \
      --color light \
      --opacity normal \
      --scheme nord \
      --dest $out/share/themes

    jdupes --quiet --link-soft --recurse $out/share

    runHook postInstall
  '';

  meta = {
    description = "macOS Sequoia-like Gtk theme";
    homepage = "https://github.com/vinceliuice/MacTahoe-gtk-theme";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
