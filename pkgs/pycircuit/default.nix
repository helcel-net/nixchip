{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  python3,
  makeWrapper,
  llvmPackages_22,
  version ? "unstable-2026-10-23",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "047967b37a21bd298d174aaef1a2bbb5053c8f3f"
    else
      "v${version}",
  hash ? "sha256-ux40qqHO2CJD2q0pa2FC8FtvwYfxIbr5V2O6DyEz8Wc=",
}:

let
  inherit (llvmPackages_22) llvm mlir tblgen;

  # Releases up to 6.1.x ship the PYC/pycc toolchain; main has since been
  # rewritten around ACIR with a different CMake and Python layout.
  pyccLayout = !lib.hasPrefix "unstable-" version && lib.versionOlder version "6.2";

  setTablegen = ''set(MLIR_TABLEGEN_EXE \"${tblgen}/bin/mlir-tblgen\")'';
in
stdenv.mkDerivation {
  pname = "pycircuit";
  inherit version;

  src = fetchFromGitHub {
    owner = "PTO-ISA";
    repo = "pyCircuit";
    inherit rev hash;
  };

  # Upstream locks LLVM/MLIR to an exact patch release. The llvmPackages_22
  # input already selects the series, so drop the CMake version check and let
  # a nixpkgs point-release bump through.
  #
  # nixpkgs' MLIRConfig.cmake sets a bare "mlir-tblgen" (overriding any -D
  # flag) on every find_package(MLIR); the tool ships in the separate tblgen
  # package.
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail "find_package(LLVM 22.1.8 EXACT" "find_package(LLVM" \
      --replace-fail "find_package(MLIR 22.1.8 EXACT CONFIG REQUIRED)" \
        "find_package(MLIR CONFIG REQUIRED)
    ${setTablegen}"
  ''
  + lib.optionalString pyccLayout ''
    substituteInPlace compiler/mlir/CMakeLists.txt \
      --replace-fail "find_package(MLIR REQUIRED CONFIG)" \
        "find_package(MLIR REQUIRED CONFIG)
    ${setTablegen}"
    substituteInPlace compiler/acir/cmake/LLVMToolchain.cmake \
      --replace-fail '"22.1.8"' '"${llvm.version}"'
  '';

  nativeBuildInputs = [
    cmake
    ninja
    python3
  ]
  ++ lib.optional pyccLayout makeWrapper;

  buildInputs = [
    llvm
    mlir
    python3
  ];

  cmakeFlags = [
    # Copies the LLVM/MLIR shared libraries into $out/lib and rewrites rpaths
    # for relocatable SDK tarballs; the store paths already resolve.
    (lib.cmakeBool "PYC_PACKAGE_BUNDLE_RUNTIME_DEPS" false)
    # pycircuitConfig.cmake.in appends these to the package prefix, which
    # breaks with the absolute paths the cmake setup hook passes.
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_INCLUDEDIR" "include")
  ]
  # The source tarball has no .git to read the revision from.
  ++ lib.optional (!pyccLayout) (lib.cmakeFeature "PYC_TOOLCHAIN_GIT_SHA" rev)
  # pycc links the ACIR dialect, which only this subproject builds; upstream's
  # tools/pyc build script turns it on by default.
  ++ lib.optional pyccLayout (lib.cmakeBool "PYC_BUILD_AGENTIC_CIRCUIT" true);

  # pyc-opt is EXCLUDE_FROM_ALL but installed whenever MLIRRegisterAllPasses
  # exists; upstream's build script builds it as a separate target.
  ninjaFlags = lib.optionals pyccLayout [
    "all"
    "pyc-opt"
  ];

  # The release installs pycc and the frontend sources but no driver. The
  # frontend imports semantic-core, which the ACIR subproject installs to
  # site-packages, and runs the helper scripts the wheel stages in _tools.
  postInstall = lib.optionalString pyccLayout ''
    install -Dm644 -t $out/share/pycircuit/python/pycircuit/_tools \
      ../flows/tools/gen_cmake_from_manifest.py \
      ../tools/pycircuit/pyc_module_graph.py
    makeWrapper ${lib.getExe python3} $out/bin/pycircuit \
      --add-flags "-m pycircuit.cli" \
      --prefix PYTHONPATH : $out/share/pycircuit/python:$out/${python3.sitePackages} \
      --set-default PYC_TOOLCHAIN_ROOT $out
  '';

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = {
    description = "Python-syntax hardware language and MLIR compiler emitting C++ simulation models and Verilog";
    homepage = "https://github.com/PTO-ISA/pyCircuit";
    license = lib.licenses.bsd3;
    mainProgram = "pycircuit";
    platforms = lib.platforms.linux;
  };
}
