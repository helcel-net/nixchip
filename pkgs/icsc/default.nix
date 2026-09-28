{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  llvmPackages_18,
  protobuf,
  version ? "unstable-2026-09-25",
  rev ? "68e56ae742e662199b697f7535f761c8d9bfcb7b",
  hash ? "sha256-melsgKUyiv19LNLbrtFag6NZ5CfQ1iBDm/hgU1g/MZw=",
}:

let
  inherit (llvmPackages_18) llvm clang clang-unwrapped;
in
stdenv.mkDerivation {
  pname = "icsc";
  inherit version;

  src = fetchFromGitHub {
    owner = "intel";
    repo = "systemc-compiler";
    inherit rev hash;
  };

  nativeBuildInputs = [
    cmake
    protobuf
  ];

  buildInputs = [
    llvm
    clang-unwrapped
    protobuf
  ];

  # Upstream builds its own LLVM/Clang tree into ICSC_HOME, so clang++ is
  # assumed to sit next to the LLVM tools. nixpkgs ships clang separately;
  # generate the SystemC precompiled header with the wrapped clang++ so it also
  # finds the libstdc++ headers.
  #
  # sc_tool links a list of static LLVM component archives while libclang-cpp
  # pulls in the shared libLLVM, so every design's *_sctool binary carries two
  # copies of LLVM and aborts on start ("Option 'debug-counter' registered
  # more than once"). Link the single LLVM dylib instead.
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail "\''${LLVM_TOOLS_BINARY_DIR}/clang++" "${clang}/bin/clang++"
    sed -Ei 's/^([[:space:]]+)LLVM[A-Za-z0-9]+$/\1LLVM/' sc_tool/CMakeLists.txt
    # GCC 15's <cmath> declares the math functions constexpr through builtins
    # clang 18 cannot constant-fold, so the SCTool frontend rejects every design
    # (SystemC's own sc_nbutils.h includes <cmath>). The diagnostic is an error
    # by default; disable it on the frontend command line svc_target() emits.
    substituteInPlace cmake/svc_target.cmake \
      --replace-fail "-Wno-logical-op-parentheses" "-Wno-logical-op-parentheses -Wno-invalid-constexpr"
  '';

  # find_package(LLVM $ENV{LLVM_VER} EXACT ...) reads the version it accepts
  # from the environment.
  env.LLVM_VER = llvm.version;

  # setenv.sh, designs/, doc/ and the consumer-side CMakeLists.txt are
  # installed to $ENV{ICSC_HOME}, not to the install prefix.
  preConfigure = ''
    export ICSC_HOME=$out
  '';

  cmakeFlags = [ "-DCMAKE_CXX_STANDARD=20" ];

  # The installed SVCConfig.cmake hands clang's builtin headers to the SCTool
  # frontend as $ICSC_HOME/lib/clang/$LLVM_VER/include, where the self-built
  # LLVM would have put them; nixpkgs' clang keeps them under a major-only
  # directory in its lib output.
  postInstall = ''
    mkdir -p $out/lib/clang/${llvm.version}
    ln -s ${lib.getLib clang-unwrapped}/lib/clang/${lib.versions.major llvm.version}/include \
      $out/lib/clang/${llvm.version}/include
  '';

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = {
    description = "Intel SystemC Compiler: translates synthesizable SystemC to synthesizable SystemVerilog";
    homepage = "https://github.com/intel/systemc-compiler";
    license = with lib.licenses; [
      asl20
      llvm-exception
    ];
    platforms = lib.platforms.linux;
  };
}
