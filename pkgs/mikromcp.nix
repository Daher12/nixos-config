{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
}:
let
  version = "1.16.0";
  # Two derivations because the npm registry tarball ships no
  # package-lock.json (npm pack drops it), and buildNpmPackage's
  # npmDepsHash fingerprinting requires one. The lockfile is vendored in
  # this directory (from the package's repo at the tagged version) and
  # injected into the unpacked tarball before the npm build runs.
  srcWithLock = stdenv.mkDerivation {
    pname = "mikromcp-src";
    inherit version;
    src = fetchurl {
      url = "https://registry.npmjs.org/mikromcp/-/mikromcp-${version}.tgz";
      hash = "sha256-3PNzib7D089m8+6Jdi8Fi5vqQXiropzqd+L+oSQeqZk=";
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

  npmDepsHash = "sha256-O+aexHRur/JrwJu9pDNrYSF99xUXoIgyi0oUn+Lteq0=";

  dontNpmBuild = true;

  meta = {
    description = "Production-grade MCP server for MikroTik RouterOS";
    homepage = "https://github.com/AliKarami/MikroMCP";
    license = lib.licenses.mit;
    mainProgram = "mikromcp";
    platforms = lib.platforms.linux;
  };
}
