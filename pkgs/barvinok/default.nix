# barvinok — counts integer points in parametric polytopes. Timeloop v4 links
# it unconditionally (src/SConscript: LIBS = ['barvinok', 'isl', 'ntl',
# 'pthread', 'polylibgmp', 'gmp']), and nixpkgs does not package it.
#
# The release tarball bundles its own isl/ and polylib/ (each with its own
# configure script), and both are used rather than nixpkgs' — nixpkgs ships isl
# 0.20 and no polylib at all, and barvinok pins the isl revision it was tested
# against.
{
  lib,
  stdenv,
  fetchurl,
  gmp,
  ntl,
  autoconf,
  automake,
  libtool,
  pkg-config,
  perl,
  version ? "0.41.6",
  hash ? "sha256-HmR/hHr0T87Q61VLgkUvL/epqyvLYY7uOknkTrT4st0=",
}:

stdenv.mkDerivation {
  pname = "barvinok";
  inherit version;

  src = fetchurl {
    url = "https://barvinok.sourceforge.io/barvinok-${version}.tar.xz";
    inherit hash;
  };

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    pkg-config
    perl
  ];
  buildInputs = [
    gmp
    ntl
  ];

  configureFlags = [
    "--with-isl=bundled"
    "--with-polylib=bundled"
    "--with-ntl-prefix=${ntl}"
    "--with-gmp-prefix=${gmp.dev}"
  ];

  # polylib is pre-C99 and GCC 14 promotes implicit declarations/ints to hard
  # errors, which breaks its bundled test applications (not the library).
  env.NIX_CFLAGS_COMPILE = toString [
    "-Wno-implicit-function-declaration"
    "-Wno-implicit-int"
    "-Wno-incompatible-pointer-types"
    "-Wno-return-mismatch"
  ];

  enableParallelBuilding = true;

  passthru.nixchipCI = true;

  meta = with lib; {
    description = "Counts integer points in parametric polytopes; a Timeloop v4 link dependency";
    homepage = "https://barvinok.sourceforge.io/";
    license = licenses.gpl2Plus;
    platforms = platforms.unix;
  };
}
