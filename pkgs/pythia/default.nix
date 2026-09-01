{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  version ? "unstable-2026-02-21",
  rev ? "2626efe006a525dd9318e653b9c0198141d72f4d",
  hash ? "sha256-/qqQrhiTdA/3TfIY46sLByKj7Pm8F1SenKIZGjrA2eY=",
}:

let
  # Pythia's README asks the user to clone mavam/libbf into the source tree
  # and build it there; vendor a pinned checkout instead.
  libbfSrc = fetchFromGitHub {
    owner = "mavam";
    repo = "libbf";
    rev = "4c9efc1a4db7ed1ccf54cf0bd3a3641ce579206c";
    hash = "sha256-vX/3iw3h+J29GeSsEa4VmrNm/eCHXeNpC06WzY4/o9Y=";
  };
in
stdenv.mkDerivation {
  pname = "pythia";
  inherit version;

  src = fetchFromGitHub {
    owner = "CMU-SAFARI";
    repo = "Pythia";
    inherit rev hash;
  };

  nativeBuildInputs = [ cmake ];
  dontUseCmakeConfigure = true;

  postPatch = ''
    cp -r ${libbfSrc} libbf
    chmod -R u+w libbf
    patch -d libbf -p1 < patches/17-cannot-compile-libbf.patch
    # Pythia's headers use uint*_t without including <cstdint>, which GCC 13+
    # no longer provides transitively; force-include it for every TU.
    substituteInPlace Makefile \
      --replace-fail '-std=c++11' '-std=c++11 -include cstdint'
  '';

  # libbf forbids in-source cmake builds; the Pythia Makefile links the static
  # library from libbf/build/lib/libbf.a.
  configurePhase = ''
    runHook preConfigure
    cmake -S libbf -B libbf/build -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    runHook postConfigure
  '';

  # build_champsim.sh copies the chosen *.pref files over the placeholder
  # prefetcher sources and runs make; "multi" is the runtime-configurable
  # driver that selects the actual prefetcher (Pythia/scooby, bingo, spp, ...)
  # via --config/knob files, so one binary covers the shipped experiments.
  buildPhase = ''
    runHook preBuild
    make -C libbf/build -j"$NIX_BUILD_CORES" libbf_static
    export MAKEFLAGS=-j"$NIX_BUILD_CORES"
    bash ./build_champsim.sh multi multi no 1
    runHook postBuild
  '';

  # Ship the entire source tree (with the prebuilt libbf) so downstream
  # projects can copy share/pythia, drop in their own prefetcher, and rerun
  # build_champsim.sh without network access; the experiment scripts expect
  # binaries under $PYTHIA_HOME/bin/.
  installPhase = ''
    runHook preInstall
    rm -rf obj
    find . -name '*.bak' -delete
    mkdir -p "$out/share"
    cp -r . "$out/share/pythia"
    mkdir -p "$out/bin"
    ln -s "$out/share/pythia/bin/perceptron-multi-multi-no-ship-1core" "$out/bin/pythia"
    runHook postInstall
  '';

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = {
    description = "Pythia RL-based prefetching framework on ChampSim (CMU-SAFARI, MICRO'21)";
    homepage = "https://github.com/CMU-SAFARI/Pythia";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "pythia";
    platforms = lib.platforms.linux;
  };
}
