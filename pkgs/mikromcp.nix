{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
}:
let
  version = "1.14.0";
  srcWithLock = stdenv.mkDerivation {
    pname = "mikromcp-src";
    inherit version;
    src = fetchurl {
      url = "https://registry.npmjs.org/mikromcp/-/mikromcp-${version}.tgz";
      hash = "sha256-sNu/1GoXz1E7tdGxzUjSDYGBCA+h8Xx7emJUOI4rLXA=";
    };
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      tar -xzf $src --strip-components=1 -C $out
      cp ${./mikromcp-package-lock.json} $out/package-lock.json
      runHook postInstall
    '';
  };
in
buildNpmPackage {
  pname = "mikromcp";
  inherit version;
  src = srcWithLock;

  npmDepsHash = "sha256-0UGVcE7hngboVUl3NeEw3edaagFZGbF8E0rxItFv54M=";

  dontNpmBuild = true;

  meta = {
    description = "Production-grade MCP server for MikroTik RouterOS";
    homepage = "https://github.com/AliKarami/MikroMCP";
    license = lib.licenses.mit;
    mainProgram = "mikromcp";
    platforms = lib.platforms.linux;
  };
}
