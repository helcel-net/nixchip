{
  lib,
  stdenv,
  fetchFromGitHub,
  dtc,
  version ? "unstable-2024-01-30",
  rev ? "904336ace4c656fea0307ab7a1c5e424efd40b33",
  hash ? "sha256-PuqB4ezgCT+ctQgDut0/18OUoes7DIYww4LlT1Va38Q=",
}:

stdenv.mkDerivation {
  pname = "riscv-pulp-spike";
  inherit version;

  src = fetchFromGitHub {
    owner = "pulp-platform";
    repo = "mempool";
    inherit rev hash;
  };

  sourceRoot = "source/toolchain/riscv-isa-sim";

  postPatch = ''
    patchShebangs scripts/*.sh
    sed -i '/#define _DEVICE_H/a #include <stdint.h>' fesvr/device.h
  '';

  buildInputs = [ dtc ];

  meta = {
    description = "PULP fork of the Spike RISC-V ISA simulator";
    homepage = "https://github.com/pulp-platform/mempool";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
}
