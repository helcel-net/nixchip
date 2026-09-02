{
  lib,
  stdenv,
  fetchFromGitHub,
  scons,
  python3,
  pkg-config,
  m4,
  zlib,
  protobuf,
  gperftools,
  version ? "25.1.0.1",
  rev ? "v25.1.0.1",
  hash ? "sha256-miL4VC3M/w2bi46AG8YXgsz8duzPuJRzjN44BDaebF0=",
}:

stdenv.mkDerivation {
  pname = "gem5";
  inherit version;

  src = fetchFromGitHub {
    owner = "gem5";
    repo = "gem5";
    inherit rev hash;
  };

  nativeBuildInputs = [
    scons
    python3
    pkg-config
    m4
  ];

  buildInputs = [
    python3
    zlib
    protobuf
    gperftools
  ];

  postPatch = ''
    patchShebangs --build .
  '';

  enableParallelBuilding = true;

  # Only build the RISC-V target: a full multi-ISA build is enormous, and
  # RISC-V is the ISA this repo's ecosystem targets (spike, PULP, chipyard).
  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    scons build/RISCV/gem5.opt --ignore-style -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 build/RISCV/gem5.opt "$out/bin/gem5.opt"
    mkdir -p "$out/share/gem5"
    cp -r configs "$out/share/gem5/configs"
    runHook postInstall
  '';

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
    # gem5 releases are tagged vMAJOR.MINOR...; pin the tag shape explicitly
    # so the update bot tracks the latest release instead of branch HEAD.
    nixchipUpdateFlags = [ "--version-regex=^v([0-9.]+)$" ];
  };
  # Release-pinned (no "unstable" in the version), but still built and cached
  # on every main push: gem5 is far too expensive for downstream users to
  # build from source, which is the whole point of providing it.
  passthru.nixchipCIDefault = true;

  meta = {
    description = "Modular platform for computer-system architecture research (RISC-V build)";
    homepage = "https://www.gem5.org";
    license = lib.licenses.bsd3;
    mainProgram = "gem5.opt";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
