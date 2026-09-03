{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "Jan";
  version = "0.8.4";

  src = fetchurl {
    url = "https://github.com/janhq/jan/releases/download/v${version}/jan_${version}_amd64.AppImage";
    hash = "sha256-NNTIq02kisIjINS2TCh0Rb2UyRMSlJLR2+uzZmWxSVo=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/Jan.desktop -t $out/share/applications
    cp -r ${appimageContents}/usr/share/icons $out/share
  '';

  meta = {
    description = "Jan is an open source alternative to ChatGPT that runs 100% offline on your computer";
    homepage = "https://github.com/janhq/jan";
    license = lib.licenses.asl20;
    mainProgram = "Jan";
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
