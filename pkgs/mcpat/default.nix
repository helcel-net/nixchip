{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  version,
  hash,
}:

stdenv.mkDerivation {
  pname = "mcpat";
  inherit version;

  src = fetchFromGitHub {
    owner = "HewlettPackard";
    repo = "mcpat";
    rev = "v${version}";
    inherit hash;
  };

  enableParallelBuilding = true;

  postPatch = ''
    substituteInPlace mcpat.mk \
      --replace-fail "SHELL = /bin/sh" "SHELL = ${stdenv.shell}" \
      --replace-fail " -msse2 -mfpmath=sse" "" \
      --replace-fail "CXX = g++ -m32" "CXX = ${stdenv.cc.targetPrefix}c++" \
      --replace-fail "CC  = gcc -m32" "CC  = ${stdenv.cc.targetPrefix}cc"
  '';

  buildPhase = ''
    runHook preBuild
    make -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 mcpat "$out/bin/mcpat"
    mkdir -p "$out/share/mcpat"
    cp -R XML_PARSER *.xml "$out/share/mcpat/" 2>/dev/null || true
    install -Dm644 README "$out/share/doc/mcpat/README"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };
  passthru.nixchipUpdate = true;
  passthru.nixchipCI = true;

  meta = {
    description = "Power, area, and timing modeling framework for multicore architectures";
    homepage = "https://github.com/HewlettPackard/mcpat";
    license = lib.licenses.bsd3;
    mainProgram = "mcpat";
    platforms = lib.platforms.unix;
  };
}
