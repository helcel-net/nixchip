{
  lib,
  stdenv,
  fetchFromGitHub,
  ocamlPackages,
  dune_3,
  version ? "unstable-2026-09-02",
  rev ? "e0efabfc3ed796972d9885f9ad66e475feac7733",
  hash ? "sha256-9wA0cBjy88S4XVGv1a1+b8EY6JbnmPIymQHjF/jm/FA=",
}:

stdenv.mkDerivation {
  pname = "aslref";
  inherit version;

  # PTO-ISA's herdtools7 fork, which pto-spec pins in .aslref-origin.
  src = fetchFromGitHub {
    owner = "PTO-ISA";
    repo = "herdtools7";
    inherit rev hash;
  };

  nativeBuildInputs = [
    dune_3
  ]
  ++ (with ocamlPackages; [
    ocaml
    findlib
    menhir
  ]);

  buildInputs = with ocamlPackages; [
    menhirLib
    zarith
  ];

  # Only the ASL reference interpreter; the ASL stdlib is compiled into it.
  buildPhase = ''
    runHook preBuild
    dune build --profile release -j $NIX_BUILD_CORES asllib/aslref.exe
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 _build/default/asllib/aslref.exe $out/bin/aslref
    runHook postInstall
  '';

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = {
    description = "ASLRef, the Arm ASL reference interpreter, from PTO-ISA's herdtools7 fork";
    homepage = "https://github.com/PTO-ISA/herdtools7";
    license = lib.licenses.cecill-b;
    mainProgram = "aslref";
    platforms = lib.platforms.unix;
  };
}
