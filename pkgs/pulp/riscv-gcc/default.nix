{
  lib,
  stdenv,
  fetchFromGitHub,
  gmp,
  mpfr,
  libmpc,
  isl,
  zlib,
  flex,
  perl,
  texinfo,
  bison,
  python3,
  curl,
  version ? "unstable-2024-01-30",
  rev ? "70acebe256fc49114b5f068fa79f03eb9affed09",
  hash ? "sha256-Rb29pIiDq+kzUEe58QO/vLWFtp4xwTPGysiZ2PnY86E=",
}:

stdenv.mkDerivation {
  pname = "riscv-pulp-gcc";
  inherit version;

  src = fetchFromGitHub {
    owner = "pulp-platform";
    repo = "pulp-riscv-gnu-toolchain";
    inherit rev hash;
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    flex
    perl
    texinfo
    bison
    python3
    curl
  ];

  buildInputs = [
    gmp
    mpfr
    libmpc
    isl
    zlib
  ];

  env = {
    NIX_CFLAGS_COMPILE = "-std=gnu17 -Wno-format-security -Wno-implicit-function-declaration";
    NIX_CXXFLAGS_COMPILE = "-Wno-format-security -Wno-implicit-function-declaration";
  };

  postPatch = ''
    sed -i '1i#include <isl/space.h>' riscv-gcc/gcc/graphite.h
    sed -i '2i#include <isl/id.h>' riscv-gcc/gcc/graphite.h
    sed -i '1i#include <dlfcn.h>' riscv-gcc/gcc/plugin.c
  '';

  configurePhase = ''
    runHook preConfigure

    ./configure \
      --prefix=$out \
      --with-arch=rv32im \
      --with-cmodel=medlow \
      --enable-multilib

    runHook postConfigure
  '';

  makeFlags = [ "MAKEINFO=true" ];

  installPhase = ''
    runHook preInstall

    make install
    mkdir -p $out/riscv32-unknown-elf/lib $out/lib
    cp $src/riscv.ld $out/riscv32-unknown-elf/lib/
    cp $src/riscv.ld $out/lib/

    runHook postInstall
  '';

  meta = {
    description = "PULP RISC-V GNU toolchain";
    homepage = "https://github.com/pulp-platform/pulp-riscv-gnu-toolchain";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
