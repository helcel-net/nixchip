{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  yosys,
  nix-update-script,
  version ? "unstable-2026-11-24",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "d35005d5a794d800484782baf840f8ccee88a649"
    else
      "v${version}",
  hash ? "sha256-OxGVT6P3mFoV+y3mclfzHq3TJecO31rR3liKgs66kIw=",
}:

let
  pythonEnv = python3.withPackages (ps: [ ps.click ]);
in
stdenv.mkDerivation {
  pname = "eqy";
  inherit version;

  # .gittag is export-subst'd with %(describe), so GitHub's tarball for a
  # fixed rev changes whenever upstream adds a tag. A git checkout leaves it
  # unexpanded; the version string comes from postPatch either way.
  src = fetchFromGitHub {
    owner = "YosysHQ";
    repo = "eqy";
    forceFetchGit = true;
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
}
