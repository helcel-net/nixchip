{
  lib,
  stdenv,
  fetchFromGitHub,
  systemc,
  yaml-cpp,
  version ? "unstable-2026-11-10",
  rev ? "f23e53bef572b7117333099e12c4fe7601eb9e96",
  hash ? "sha256-xR0VxCEJGZIRGTcfvbB+eSKyKeg/LRpK2tUie0oqUfA=",
}:

stdenv.mkDerivation {
  pname = "noxim";
  inherit version;

  src = fetchFromGitHub {
    owner = "davidepatti";
    repo = "noxim";
    inherit rev hash;
  };

  buildInputs = [
    systemc
    yaml-cpp
  ];

  postPatch = ''
    # The linker command pipes through c++filt, which hides link failures.
    substituteInPlace bin/Makefile \
      --replace-fail " 2>&1 | c++filt" ""
  '';

  enableParallelBuilding = true;

  # Do not use upstream's build.sh: it downloads SystemC 2.3.1 and clones
  # yaml-cpp at build time. Instead point the Makefile at the nix-provided
  # dependencies. SystemC 2.3.4 is built with C++14, so noxim must be
  # compiled with the same standard (upstream defaults to C++11).
  buildPhase = ''
    runHook preBuild
    make -C bin -j"$NIX_BUILD_CORES" \
      CXX="${stdenv.cc.targetPrefix}c++" \
      SYSTEMC="${systemc}" \
      SYSTEMC_LIBS="${systemc}/lib" \
      YAML="${yaml-cpp}" \
      OTHER="-Wall -DSC_NO_WRITE_CHECK --std=c++14"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/noxim "$out/bin/noxim"
    install -Dm644 bin/power.yaml "$out/share/noxim/power.yaml"
    cp -r config_examples "$out/share/noxim/config_examples"
    runHook postInstall
  '';

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = {
    description = "Cycle-accurate Network-on-Chip simulator based on SystemC";
    homepage = "https://github.com/davidepatti/noxim";
    license = lib.licenses.gpl2Only;
    mainProgram = "noxim";
    platforms = lib.platforms.unix;
  };
}
