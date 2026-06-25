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
  nix-update-script,
  version,
  rev,
  fetchSubmodules ? true,
  hash,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "vtr";
  inherit version;

  src = fetchFromGitHub {
    owner = "verilog-to-routing";
    repo = "vtr-verilog-to-routing";
    inherit rev fetchSubmodules hash;
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

  passthru.updateScript = nix-update-script {
    attrPath = "vtr";
    extraArgs = [ "--version=branch" ];
  };
  passthru.nixchipUpdate = true;
  passthru.nixchipCI = true;

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
