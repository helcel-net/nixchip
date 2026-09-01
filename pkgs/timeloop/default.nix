# Timeloop v4, built from source. nixpkgs' timeloop is 3.0.3, whose binaries
# reject v4 front-end (timeloopfe) config files ("ERROR: key not found:
# data-spaces"). barvinok is the dependency that historically forced Docker for
# a hermetic v4: src/SConscript links it unconditionally and nixpkgs does not
# package it; pkgs/barvinok supplies it, along with the bundled isl and polylib
# it ships.
#
# NVlabs/timeloop, not Accelergy-Project/timeloop — the Accelergy-Project
# fork's master is over a year older and still spells config keys `data-spaces`
# where the front-end emits `data_spaces`. Pinned to the exact commit the
# accelergy-timeloop-infrastructure Docker image records, so results reproduce
# that image's energy numbers; not auto-updated for the same reason.
{
  lib,
  stdenv,
  fetchFromGitHub,
  scons,
  barvinok,
  boost,
  gmp,
  libconfig,
  ncurses,
  ntl,
  yaml-cpp,
  version ? "4.0-unstable-2025-06-09",
  rev ? "32370826fdf1aa3c8deb0c93e6b2a2fc7cf053aa",
  hash ? "sha256-1TD+qkjDx3gf0z62m/OEFEVh1KqW53xg03VY8xsP6ZE=",
}:

stdenv.mkDerivation {
  pname = "timeloop";
  inherit version;

  src = fetchFromGitHub {
    owner = "NVlabs";
    repo = "timeloop";
    inherit rev hash;
  };

  nativeBuildInputs = [ scons ];
  buildInputs = [
    barvinok
    boost
    gmp
    libconfig
    ncurses
    ntl
    yaml-cpp
  ];

  # Timeloop's SConstruct reads its dependency locations from the environment
  # rather than pkg-config, so each is pointed at explicitly.
  BOOSTDIR = boost;
  LIBCONFIGPATH = libconfig;
  YAMLCPPPATH = yaml-cpp;
  BARVINOKPATH = barvinok;
  NTLPATH = ntl;

  # GCC 13 stopped including <cstdint> transitively, and this source predates
  # that: headers use std::uint64_t without including it.
  env.NIX_CFLAGS_COMPILE = "-include cstdint";

  # src/pat is a symlink the upstream build expects the user to create by hand
  # (README: `ln -s pat-public/src/pat src/pat`); the repo ships pat-public/
  # but not the link.
  postPatch = ''
    ln -sfn ../pat-public/src/pat src/pat
  '';

  buildPhase = ''
    runHook preBuild
    # --accelergy makes the binaries call out to the Accelergy front-end for
    # energy estimation (ERT/ART). Dynamic linking (upstream's default):
    # --static asks for -lpthread, which modern glibc no longer ships as a
    # separate archive, and for static copies of libconfig/yaml-cpp that
    # nixpkgs splits across outputs.
    scons -j''${NIX_BUILD_CORES:-4} --accelergy
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib
    for f in build/timeloop-*; do
      [ -f "$f" ] && [ -x "$f" ] && install -Dm755 "$f" "$out/bin/$(basename "$f")"
    done
    for f in lib/*.a lib/*.so*; do
      [ -e "$f" ] && install -Dm644 "$f" "$out/lib/$(basename "$f")" || true
    done
    runHook postInstall
  '';

  # Both install loops tolerate an empty glob, so a change in upstream's build
  # layout would produce an empty-but-green package. Assert on the two binaries
  # timeloopfe actually drives, not the full set of six, which upstream may
  # grow or shrink.
  postInstall = ''
    for bin in timeloop-mapper timeloop-model; do
      [ -x "$out/bin/$bin" ] || { echo "missing $bin — install globs matched nothing?" >&2; exit 1; }
    done
  '';

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = with lib; {
    description = "Timeloop v4 — accelerator mapping/model tool (the binaries timeloopfe drives)";
    homepage = "https://github.com/NVlabs/timeloop";
    license = licenses.bsd3;
    platforms = platforms.linux;
  };
}
