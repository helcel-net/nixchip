{
  fetchFromGitHub,
  yosys,
  lib,
  stdenv,
  bison,
  cmake,
  flex,
  gtest,
  libffi,
  ninja,
  pkg-config,
  python3,
  readline,
  tcl,
  zlib,
  nix-update-script,
  version ? "unstable-2026-09-15",
  rev ? "d85872386aa9194e9934562db21b52625adc1e6a",
  hash ? "sha256-ga1sCMthfvDxrG05HnpRV2yjazOkUcnfttELjr4lNeo=",
  useCmake ? false,
  ...
}:

let
  src = fetchFromGitHub {
    owner = "YosysHQ";
    repo = "yosys";
    fetchSubmodules = true;
    inherit rev hash;
  };
in
if useCmake then
  stdenv.mkDerivation {
    pname = "yosys";
    inherit version src;

    nativeBuildInputs = [
      bison
      cmake
      flex
      ninja
      pkg-config
      python3
    ];

    buildInputs = [
      gtest
      libffi
      readline
      tcl
      zlib
    ];

    # GCC 15.2's ivopts pass folds a bogus -2^34 constant into the 32-bit
    # local-dynamic TLS displacement of ABC's thread-local scratch arrays
    # (abc/src/opt/dau/dauCanon.c), so linking yosys-abc fails with
    # "relocation truncated to fit: R_X86_64_DTPOFF32". GCC 15.3 no longer
    # does this. ABC is only linked into the standalone yosys-abc executable
    # on Linux, where the linker relaxes TLS to initial-exec anyway; asking
    # for it up front keeps the offset in a 64-bit GOT slot the bug can't
    # reach. Drop once nixpkgs' gcc is >= 15.3.
    postPatch = ''
      substituteInPlace cmake/YosysAbc.cmake \
        --replace-fail $'\t\t-fpermissive\n' \
          $'\t\t-ftls-model=initial-exec\n\t\t-fpermissive\n'
    '';

    cmakeFlags = [
      (lib.cmakeBool "YOSYS_SKIP_ABC_SUBMODULE_CHECK" true)
      (lib.cmakeFeature "YOSYS_CHECKOUT_INFO" rev)
    ];

    enableParallelBuilding = true;

    passthru = {
      updateScript = nix-update-script { };
      nixchipUpdate = true;
      nixchipCI = true;
    };

    meta = (yosys.meta or { }) // {
      mainProgram = yosys.meta.mainProgram or "yosys";
    };
  }
else
  yosys.overrideAttrs (old: {
    inherit version src;
    meta = (old.meta or { }) // {
      mainProgram = old.meta.mainProgram or "yosys";
    };
    passthru = (old.passthru or { }) // {
      updateScript = nix-update-script { };
      nixchipUpdate = true;
      nixchipCI = true;
    };
  })
