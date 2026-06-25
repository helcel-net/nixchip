{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  version,
  rev,
  hash,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "cacti";
  inherit version;

  src = fetchFromGitHub {
    owner = "HewlettPackard";
    repo = "cacti";
    inherit rev hash;
  };

  postPatch = ''
    substituteInPlace cacti.mk \
      --replace-fail "SHELL = /bin/sh" "SHELL = ${stdenv.shell}" \
      --replace-fail " -msse2 -mfpmath=sse" ""

    substituteInPlace cacti.mk \
      --replace-quiet "CXX = g++ -m32" "CXX = ${stdenv.cc.targetPrefix}c++" \
      --replace-quiet "CC  = gcc -m32" "CC  = ${stdenv.cc.targetPrefix}cc" \
      --replace-quiet "CXX = g++ -m64" "CXX = ${stdenv.cc.targetPrefix}c++" \
      --replace-quiet "CC  = gcc -m64" "CC  = ${stdenv.cc.targetPrefix}cc"
  '';

  enableParallelBuilding = true;

  passthru.updateScript = nix-update-script {
    attrPath = "cacti";
    extraArgs = [ "--version=branch" ];
  };
  passthru.nixchipUpdate = true;
  passthru.nixchipCI = true;

  buildPhase = ''
    runHook preBuild
    make opt NTHREADS=$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 cacti "$out/bin/cacti"
    install -Dm644 cache.cfg "$out/share/cacti/cache.cfg"
    install -Dm644 dram.cfg "$out/share/cacti/dram.cfg"
    install -Dm644 README "$out/share/doc/cacti/README"
    runHook postInstall
  '';

  meta = {
    description = "Analytical cache and memory modeling tool";
    homepage = "https://github.com/HewlettPackard/cacti";
    license = lib.licenses.bsd3;
    mainProgram = "cacti";
    platforms = lib.platforms.unix;
  };
})
