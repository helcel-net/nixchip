{
  lib,
  stdenv,
  fetchFromGitHub,
  flex,
  bison,
  version ? "unstable-2017-06-27",
  rev ? "28f43299f1706a3160ffac721ca461d74eb6e618",
  hash ? "sha256-An8BikrHg5aZyHtJA/X3UsVMEk27iduN8f77Unyve9Y=",
}:

stdenv.mkDerivation {
  pname = "booksim2";
  inherit version;

  src = fetchFromGitHub {
    owner = "booksim";
    repo = "booksim2";
    inherit rev hash;
  };

  nativeBuildInputs = [
    flex
    bison
  ];

  enableParallelBuilding = true;

  passthru.nixchipCI = true;

  buildPhase = ''
    runHook preBuild
    make -C src -j$NIX_BUILD_CORES LEX=flex YACC="bison -y"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 src/booksim "$out/bin/booksim"
    mkdir -p "$out/share/booksim2"
    cp -r runfiles "$out/share/booksim2/runfiles"
    cp -r src/examples "$out/share/booksim2/examples"
    runHook postInstall
  '';

  meta = {
    description = "Cycle-accurate interconnection network simulator";
    homepage = "https://github.com/booksim/booksim2";
    license = lib.licenses.bsd3;
    mainProgram = "booksim";
    platforms = lib.platforms.unix;
  };
}
