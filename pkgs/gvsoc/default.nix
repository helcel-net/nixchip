{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  python3,
  lz4,
  zlib,
  makeWrapper,
  nix-update-script,
  version ? "unstable-2026-06-22",
  rev ? "8db8bb09a7206e768c080aaa6c191f9a8fd1c122",
  hash ? "sha256-W0W6tp+zJm9+2lbFr7gzLf1123MRJZ4MhPelH90kh3E=",
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
