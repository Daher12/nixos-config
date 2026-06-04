{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
}:

let
  version = "2.8.2";
  pname = "msty";

  src = fetchurl {
    url = "https://assets.msty.app/prod/latest/linux/amd64/Msty_x86_64_amd64.AppImage";
    hash = "sha256-Z4t0EcV9X4g5X0lBwipiMdP8lgPuBkhykAIKjHSUpnI=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  extraPkgs = pkgs: [
    pkgs.libsecret
    pkgs.xorg.libxcb
  ];

  extraInstallCommands = ''
    wrapProgram $out/bin/${pname} --add-flags "--no-sandbox"

    install -m 444 -D ${appimageContents}/${pname}.desktop $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'

    cp -r ${appimageContents}/usr/share/icons $out/share
  '';

  meta = {
    description = "Private AI workspace for chat, media, and automation";
    homepage = "https://msty.ai";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
