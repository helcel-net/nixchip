# 3D-ICE — EPFL ESL's 3D Interlayer Cooling Emulator: transient/steady-state
# thermal simulation of vertically stacked 3D ICs with inter-tier microchannel
# liquid cooling. Not packaged in nixpkgs.
#
# The build has several landmines, all encoded below:
#
#  * The sparse solver (SuperLU_MT 4.0.0) is bundled as a zip inside the repo
#    (hence `unzip` in nativeBuildInputs) and its code is pre-C99: modern GCC
#    (14+) rejects K&R-style unprototyped declarations ("char *getenv();") as
#    hard errors, so SuperLU_MT is compiled with -std=gnu89 plus warning
#    downgrades.
#
#  * SuperLU_MT's SRC/Makefile builds all four precisions (single, double,
#    complex, complex16) as parallel prerequisites of `all`, and each recipe
#    `ar`-appends into the SAME archive — a real race under -jN. That build
#    must run with -j1, and an inherited MAKEFLAGS must not leak parallelism
#    into it; enableParallelBuilding = false for the whole derivation is the
#    simple safe choice (3D-ICE itself is small, the cost is negligible).
#
#  * The SuperLU_MT zip ships stale prebuilt .o files compiled for ARM aarch64
#    whose mtimes survive extraction, so make considers them up to date and the
#    link fails with "Relocations in generic ELF ... wrong format". They are
#    deleted right after unzipping, before anything is built.
#
#  * SuperLU_MT needs an LP64 BLAS (32-bit integer indices): openblasCompat.
#    The default `openblas` on x86_64 is ILP64 and segfaults inside
#    SuperLU_MT's factorization at runtime.
#
#  * 3D-ICE generates its stack-description/floorplan parsers with flex and
#    bison at build time — both in nativeBuildInputs.
#
# makefile.def and SuperLU_MT's make.inc hardcode BLAS in
# /lib/x86_64-linux-gnu; both are pointed at the nix store instead.
{
  lib,
  stdenv,
  fetchFromGitHub,
  unzip,
  flex,
  bison,
  openblasCompat,
  version ? "unstable-2026-07-02",
  rev ? "4953952a1ef6d38807ff307212a6f15e5b2ef935",
  hash ? "sha256-veBCrejWa7Q4cbQISWom+pTa1W7XfMl7d5xpJrm3ihw=",
}:

stdenv.mkDerivation {
  pname = "3d-ice";
  inherit version;

  src = fetchFromGitHub {
    owner = "esl-epfl";
    repo = "3d-ice";
    inherit rev hash;
  };

  nativeBuildInputs = [
    unzip
    flex
    bison
  ];
  buildInputs = [ openblasCompat ];

  postPatch = ''
    unzip -q superlu_mt-4.0.0.zip

    # Drop the stale aarch64 .o files bundled in the zip (see header comment).
    find superlu_mt-4.0.0 -name '*.o' -delete

    # Configure SuperLU_MT the way upstream's install-superlumt.sh does
    # (OpenMP platform, vendor BLAS with trailing-underscore Fortran names),
    # but against the store's LP64 OpenBLAS and with -std=gnu89 for the
    # pre-C99 code.
    cp superlu_mt-4.0.0/MAKE_INC/make.linux.openmp superlu_mt-4.0.0/make.inc
    substituteInPlace superlu_mt-4.0.0/make.inc \
      --replace-fail "BLASDEF   =" "BLASDEF   = -DUSE_VENDOR_BLAS" \
      --replace-fail "BLASLIB = ../lib/libblas\$(PLAT).a" \
                     "BLASLIB = -L${openblasCompat}/lib -lopenblas" \
      --replace-fail "CDEFS        = -DNoChange" "CDEFS        = -DAdd_" \
      --replace-fail "CC           = gcc -fopenmp" \
                     "CC           = ${stdenv.cc.targetPrefix}cc -fopenmp -std=gnu89 -Wno-implicit-function-declaration -Wno-implicit-int -Wno-old-style-definition"

    # 3D-ICE's own makefile.def: use the wrapped compiler and the store BLAS.
    substituteInPlace makefile.def \
      --replace-fail "CC        = gcc" "CC        = ${stdenv.cc.targetPrefix}cc" \
      --replace-fail "-L/lib/x86_64-linux-gnu -lopenblas" \
                     "-L${openblasCompat}/lib -lopenblas"
  '';

  # SuperLU_MT's archive-append race (see header comment): keep everything
  # serial rather than trying to parallelize only the safe parts.
  enableParallelBuilding = false;

  buildPhase = ''
    runHook preBuild

    # `lib` builds only the solver library, skipping the INSTALL machine-
    # parameter self-tests. MAKEFLAGS is cleared so no -jN can leak in.
    env MAKEFLAGS= make -C superlu_mt-4.0.0 -j1 lib

    make lib bin

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 -t $out/bin \
      bin/3D-ICE-Emulator bin/3D-ICE-Client bin/3D-ICE-Server

    install -Dm644 -t $out/lib lib/*.a superlu_mt-4.0.0/lib/*.a

    # Upstream has no install target; ship the public headers so the static
    # library is usable.
    install -Dm644 -t $out/include/3d-ice include/*.h

    # Example stack descriptions and the floorplans they reference (the .stk
    # files use relative "./*.flp" paths, so run the emulator from a copy of
    # this directory).
    install -Dm644 -t $out/share/3d-ice bin/*.stk bin/*.flp

    runHook postInstall
  '';

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = with lib; {
    description = "Thermal emulator for vertically stacked 3D integrated circuits with inter-tier liquid cooling";
    homepage = "https://github.com/esl-epfl/3d-ice";
    license = licenses.gpl3Plus;
    mainProgram = "3D-ICE-Emulator";
    platforms = platforms.linux;
  };
}
