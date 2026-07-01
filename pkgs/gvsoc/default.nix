{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  python3,
  lz4,
  zlib,
  elfutils,
  makeWrapper,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ? "4a97a61275a7e26260c0103e0059422177ac6432",
  hash ? "sha256-WnwVvTTuESm8rvS2+C3jVZIy30+qIDXUTvsdfEbbFcI=",
}:

let
  pythonEnv = python3.withPackages (ps: with ps; [
    pyelftools
    prettytable
    pexpect
    lz4
    rich
    psutil
    pyyaml
    pytablewriter
    pandas
    matplotlib
    tabulate
    mako
    setuptools
    hjson
    typing-extensions
    six
  ]);
in
stdenv.mkDerivation {
  pname = "gvsoc";
  inherit version;

  src = fetchFromGitHub {
    owner = "gvsoc";
    repo = "gvsoc";
    inherit rev hash;
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    ninja
    makeWrapper
    pythonEnv
  ];

  buildInputs = [
    lz4
    zlib
    elfutils
  ];

  postPatch = ''
    patchShebangs gapy/bin/gapy gvrun/bin/gvrun
    sed -i \
      's/RESULT_VARIABLE ret$/RESULT_VARIABLE ret OUTPUT_VARIABLE gapy_out ERROR_VARIABLE gapy_err/' \
      engine/CMakeLists.txt
    sed -i \
      '/FATAL_ERROR "Caught error while generating gvsoc config"/i\        message(STATUS "GAPY stderr: ''${gapy_err}")' \
      engine/CMakeLists.txt
  '';

  dontUseCmakeConfigure = true;

  buildPhase = ''
    runHook preBuild
    mkdir -p $TMPDIR/build
    # gvrun.build installs gvrun to $out/bin; add it to PATH so cmake can call it
    export PATH="$out/bin:$PATH"
    make build -j$NIX_BUILD_CORES INSTALLDIR=$out BUILDDIR=$TMPDIR/build
    runHook postBuild
  '';

  dontInstall = true;

  postFixup = ''
    for f in $out/bin/*; do
      if head -1 "$f" 2>/dev/null | grep -q python; then
        wrapProgram "$f" --prefix PATH : ${pythonEnv}/bin
      fi
    done
  '';

  passthru = {
    updateScript = nix-update-script {
      attrPath = "gvsoc";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };

  meta = {
    description = "Virtual platform simulator for RISC-V based systems";
    homepage = "https://github.com/gvsoc/gvsoc";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
