{
  lib,
  llvmPackages,
  fetchFromGitHub,
  cmake,
  python3,
  ninja,
  version ? "unstable-2024-01-30",
  rev ? "b494f2d8dde88723026db8ec16ac6c7ee1e140ca",
  hash ? "sha256-BT6X8F0OKsSv4CyjiYuu7ZJVrZTiB38uaa0Id3BX/co=",
}:

llvmPackages.stdenv.mkDerivation {
  pname = "riscv-pulp-llvm";
  inherit version;

  src = fetchFromGitHub {
    owner = "pulp-platform";
    repo = "llvm-project";
    inherit rev hash;
  };

  nativeBuildInputs = [
    cmake
    ninja
    python3
  ];

  postPatch = ''
    sed -i '/#include <cstddef>/a #include <cstdint>' llvm/include/llvm/ADT/SmallVector.h
    sed -i '/#include <memory>/a #include <cstdint>' llvm/lib/Target/X86/MCTargetDesc/X86MCTargetDesc.h
  '';

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DLLVM_ENABLE_PROJECTS=clang"
    "-DLLVM_TARGETS_TO_BUILD=RISCV;host"
    "-DLLVM_BUILD_DOCS=0"
    "-DLLVM_ENABLE_BINDINGS=0"
    "-DLLVM_ENABLE_TERMINFO=0"
    "-DLLVM_ENABLE_ASSERTIONS=ON"
    "-DLLVM_ENABLE_LIBPFM=OFF"
  ];

  cmakeDir = "../llvm";

  meta = {
    description = "PULP RISC-V LLVM toolchain";
    homepage = "https://github.com/pulp-platform/llvm-project";
    license = lib.licenses.ncsa;
    platforms = lib.platforms.unix;
  };
}
