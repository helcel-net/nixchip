{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  yosys,
  nix-update-script,
  version ? "0.47",
  rev ? "yosys-${version}",
  hash ? "sha256-TH2wNvVi338JkxUsExUg2/JVdU3CWJ9MPKtitM/1Y00=",
}:

let
  isBranch = lib.hasInfix "unstable" version;
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

  passthru.updateScript = if isBranch
    then nix-update-script { attrPath = "eqy"; extraArgs = [ "--version=branch" ]; }
    else nix-update-script { extraArgs = [ "--version-regex=^yosys-(0\\.[0-9.]+[a-z]?)$" ]; };
  # Tags use yosys-0.47 format; instruct update-packages.sh to use the matching regex.
  # Branch builds are detected by "unstable" in version and handled separately.
  passthru.nixchipUpdateFlags = lib.optionals (!isBranch) [
    "--version-regex=^yosys-(0\\.[0-9.]+[a-z]?)$"
  ];
  # Branch builds have version/rev/hash in pkgs/default.nix (call site), so nix-update
  # cannot edit them automatically. Only the stable default call is auto-updatable.
  passthru.nixchipUpdate = !isBranch;
  passthru.nixchipCI = true;

  meta = {
    description = "Equivalence checker for digital circuits, based on Yosys";
    homepage = "https://github.com/YosysHQ/eqy";
    license = lib.licenses.isc;
    mainProgram = "eqy";
    platforms = lib.platforms.unix;
  };
})
