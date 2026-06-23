{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  yosys,
  rev ? "yosys-0.47",
  hash ? "sha256-TH2wNvVi338JkxUsExUg2/JVdU3CWJ9MPKtitM/1Y00=",
}:

let
  pythonEnv = python3.withPackages (ps: [ ps.click ]);
in

stdenv.mkDerivation (finalAttrs: {
  pname = "eqy";
  version = "0.66";

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

  meta = {
    description = "Equivalence checker for digital circuits, based on Yosys";
    homepage = "https://github.com/YosysHQ/eqy";
    license = lib.licenses.isc;
    mainProgram = "eqy";
    platforms = lib.platforms.unix;
  };
})
