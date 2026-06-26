{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  version ? "unstable-2015-09-14",
  rev ? if lib.hasPrefix "unstable-" version then "74d4759f3ba2dff8f5a69e07a68efdb46b42fb8c" else "v${version}",
  hash  ? "sha256-sr7H2vBOTyI59d3itVNqRVy1fR/83ZrTGl5s4I+g0Tw="
}:

stdenv.mkDerivation {
  pname = "mcpat";
  inherit version;

  src = fetchFromGitHub {
    owner = "HewlettPackard";
    repo = "mcpat";
    inherit rev hash;
  };

  enableParallelBuilding = true;

  postPatch = ''
    substituteInPlace mcpat.mk \
      --replace-fail "SHELL = /bin/sh" "SHELL = ${stdenv.shell}" \
      --replace-fail " -msse2 -mfpmath=sse" "" \
      --replace-fail "CXX = g++ -m32" "CXX = ${stdenv.cc.targetPrefix}c++" \
      --replace-fail "CC  = gcc -m32" "CC  = ${stdenv.cc.targetPrefix}cc"
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 mcpat "$out/bin/mcpat"
    mkdir -p "$out/share/mcpat"
    cp -R XML_PARSER *.xml "$out/share/mcpat/" 2>/dev/null || true
    install -Dm644 README "$out/share/doc/mcpat/README"

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script {
      attrPath = "mcpat";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };

  meta = {
    description = "Power, area, and timing modeling framework for multicore architectures";
    homepage = "https://github.com/HewlettPackard/mcpat";
    license = lib.licenses.bsd3;
    mainProgram = "mcpat";
    platforms = lib.platforms.unix;
  };
}
