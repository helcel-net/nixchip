{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  patchelf,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ? if lib.hasPrefix "unstable-" version then "29817593b3389f1337235d63cac515024ab8fd6e" else version,
  hash ? "sha256-uErpWJEn6C9oKR6Bv1NOAC3ij3ne3A6BPtjtX7D8ZwE=",
}:

stdenv.mkDerivation {
  pname = "dramsim3";
  inherit version;

  src = fetchFromGitHub {
    owner = "umd-memsys";
    repo = "DRAMsim3";
    inherit rev hash;
  };

  nativeBuildInputs = [
    cmake
    patchelf
  ];

  cmakeFlags = [
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  ];

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail 'LIBRARY_OUTPUT_DIRECTORY ''${PROJECT_SOURCE_DIR}' 'LIBRARY_OUTPUT_DIRECTORY ''${CMAKE_BINARY_DIR}'
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 dramsim3main "$out/bin/dramsim3"
    install -Dm755 libdramsim3.so "$out/lib/libdramsim3.so"
    patchelf --set-rpath "$out/lib:${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" "$out/bin/dramsim3"
    mkdir -p "$out/include/dramsim3" "$out/share/dramsim3"
    cp -R ../src/*.h "$out/include/dramsim3/"
    cp -R ../configs "$out/share/dramsim3/"
    cp -R ../scripts "$out/share/dramsim3/"
    install -Dm644 ../README.md "$out/share/doc/dramsim3/README.md"

    runHook postInstall
  '';

  
  passthru = {
    updateScript = nix-update-script {
      attrPath = "dramsim3_";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };

  meta = {
    description = "Cycle-accurate, thermal-capable DRAM simulator";
    homepage = "https://github.com/umd-memsys/DRAMsim3";
    license = lib.licenses.mit;
    mainProgram = "dramsim3";
    platforms = lib.platforms.unix;
  };
}
