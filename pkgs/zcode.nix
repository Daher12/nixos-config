{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "zcode";
  version = "3.10.2";

  src = fetchurl {
    url = "https://cdn-zcode.z.ai/zcode/electron/releases/${version}/linux-x64/ZCode-${version}-linux-x64.AppImage";
    hash = "sha256-b0utaKoaaQJuikXQqd8l8YaDvJpBevSDEF3L70SLqz8=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/zcode.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/zcode.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${appimageContents}/usr/share/icons $out/share
  '';

  meta = {
    description = "ZCode is next-gen vibe coding for complex goals — with multiple agents and control from anywhere";
    homepage = "https://zcode.z.ai/en";
    license = lib.licenses.unfree;
    mainProgram = "zcode";
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
