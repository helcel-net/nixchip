{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  bison,
  flex,
  python3,
  pkg-config,
  zlib,
  readline,
  version ? "9.0.0",
  tag ? "v${version}",
  fetchSubmodules ? true,
  hash ? "sha256-g5pDGy6A0e1gHFU64G7NcTAGiUj8vfyhJkQ3++4Y2yw=",
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "vtr";
  inherit version;

  src = fetchFromGitHub {
    owner = "verilog-to-routing";
    repo = "vtr-verilog-to-routing";
    inherit tag fetchSubmodules hash;
  };

  nativeBuildInputs = [
    cmake
    bison
    flex
    python3
    pkg-config
  ];

  buildInputs = [
    zlib
    readline
  ];

  cmakeFlags = [
    # disable front-ends; use system yosys / blif input directly
    (lib.cmakeBool "WITH_PARMYS" false)
    (lib.cmakeBool "WITH_ODIN" false)
    # disable optional features to reduce the dependency footprint
    (lib.cmakeBool "VPR_ANALYTIC_PLACE" false)
    (lib.cmakeBool "VTR_ENABLE_CAPNPROTO" false)
    (lib.cmakeFeature "VPR_USE_EZGL" "off")
    (lib.cmakeFeature "VPR_EXECUTION_ENGINE" "serial")
  ];

  enableParallelBuilding = true;

  postInstall = ''
    # install bundled abc built by the VTR build system
    if [ -f abc/abc ]; then
      install -Dm755 abc/abc "$out/bin/abc"
    fi

    # install the VTR flow scripts
    install -Dm755 ../vtr_flow/scripts/run_vtr_flow.py "$out/bin/run_vtr_flow.py"
    install -Dm755 ../vtr_flow/scripts/run_vtr_task.py "$out/bin/run_vtr_task.py"

    mkdir -p "$out/share/vtr"
    cp -r ../vtr_flow "$out/share/vtr/"
  '';

  meta = {
    description = "Verilog-to-Routing: open-source FPGA CAD flow for architecture research";
    homepage = "https://verilogtorouting.org";
    license = lib.licenses.mit;
    mainProgram = "vpr";
    platforms = lib.platforms.linux;
  };
})
