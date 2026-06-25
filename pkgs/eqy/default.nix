{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  yosys,
  nix-update-script,
  version ? "0-unstable-2026-06-25",
  rev ? "8770b67d0bc802f17dbc9f2393d2dbc1f14c39ee",
  hash ? "sha256-YMTWXLb9PMxps42ppkCvabPp+dDu6j+DlhQ7NQ73IoQ=",
}:

let
  pythonEnv = python3.withPackages (ps: [ ps.click ]);
in
stdenv.mkDerivation (finalAttrs: {
  pname = "eqy";
  inherit version;

  src = fetchFromGitHub {
    owner = "YosysHQ";
    repo = "eqy";
    inherit rev hash;
  };

  nativeBuildInputs = [
    yosys
    pythonEnv
  ];

  postPatch = ''
    substituteInPlace src/eqy.py \
      --replace-fail '#!/usr/bin/env python3' '#!${pythonEnv}/bin/python3' \
      --replace-fail '##yosys-sys-path##' \
        "sys.path += [\"$out/share/yosys/python3\", \"${yosys}/share/yosys/python3\"]" \
      --replace-fail '##yosys-release-version##' \
        "release_version = '${rev}'"
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    make install PREFIX="$out" YOSYS_CONFIG="${yosys}/bin/yosys-config"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    attrPath = "eqy";
    extraArgs = [ "--version=branch" ];
  };
  passthru.nixchipUpdate = true;
  passthru.nixchipCI = true;

  meta = {
    description = "Equivalence checker for digital circuits, based on Yosys";
    homepage = "https://github.com/YosysHQ/eqy";
    license = lib.licenses.isc;
    mainProgram = "eqy";
    platforms = lib.platforms.unix;
  };
})
