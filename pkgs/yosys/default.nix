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
  version ? "unstable-2026-07-02",
  rev ? "b285b72e360260be4abc8990f9c46b25b8b66b40",
  hash ? "sha256-GKS4tQH4c8NUOUgTfKbU9pESgatirDx349mvWAwt4G8=",
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
