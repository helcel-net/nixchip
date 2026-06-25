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

  postPatch = ''
    # GCC 15 no longer implicitly includes these headers
    sed -i '/#include <iostream>/a #include <cstdint>' \
      libs/librtlnumber/src/rtl_utils.cpp \
      libs/libeasygl/src/graphics_types.h
    sed -i '1i #include <limits>' \
      libs/EXTERNAL/libargparse/src/argparse.cpp
    sed -i '/#include <memory>/a #include <array>' \
      libs/libvtrutil/src/vtr_small_vector.h
    sed -i '1i #include <limits>' \
      libs/libvtrutil/src/vtr_geometry.tpp
    # SIGSTKSZ is no longer a compile-time constant in glibc 2.34+
    sed -i 's/altStackMem\[SIGSTKSZ\]/altStackMem[65536]/g' \
      libs/EXTERNAL/libcatch/catch.hpp
    # vtr 8 unconditionally adds ODIN_II; make it respect WITH_ODIN
    sed -i 's|^add_subdirectory(ODIN_II)|option(WITH_ODIN "Build ODIN II front-end" ON)\nif(WITH_ODIN)\n  add_subdirectory(ODIN_II)\nendif()|' \
      CMakeLists.txt
  '';

  cmakeFlags = [
    # disable front-ends; use system yosys / blif input directly
    (lib.cmakeBool "WITH_PARMYS" false)
    (lib.cmakeBool "WITH_ODIN" false)
    # disable optional features to reduce the dependency footprint
    (lib.cmakeBool "VPR_ANALYTIC_PLACE" false)
    (lib.cmakeBool "VTR_ENABLE_CAPNPROTO" false)
    (lib.cmakeFeature "VPR_USE_EZGL" "off")
    (lib.cmakeFeature "VPR_EXECUTION_ENGINE" "serial")
    # bundled abc uses cmake_minimum_required < 3.5 which new CMake rejects
    (lib.cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.5")
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

    # install the VTR flow scripts (added in vtr 9+)
    if [ -f ../vtr_flow/scripts/run_vtr_flow.py ]; then
      install -Dm755 ../vtr_flow/scripts/run_vtr_flow.py "$out/bin/run_vtr_flow.py"
    fi
    if [ -f ../vtr_flow/scripts/run_vtr_task.py ]; then
      install -Dm755 ../vtr_flow/scripts/run_vtr_task.py "$out/bin/run_vtr_task.py"
    fi

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
