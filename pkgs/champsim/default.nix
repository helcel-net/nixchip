{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  cli11,
  fmt,
  nlohmann_json,
  bzip2,
  xz,
  zlib,
  version ? "unstable-2026-09-15",
  rev ? "410cee62d9c429c043ea611325ce00e6c303be2a",
  hash ? "sha256-wcLQwGffhOOErB1YcdwSpH/9gWp1kSWhTKIvV9Zrq0Q=",
}:

stdenv.mkDerivation {
  pname = "champsim";
  inherit version;

  src = fetchFromGitHub {
    owner = "ChampSim";
    repo = "ChampSim";
    inherit rev hash;
  };

  nativeBuildInputs = [ python3 ];

  buildInputs = [
    cli11
    fmt
    nlohmann_json
    bzip2
    xz
    zlib
  ];

  # ChampSim normally fetches its C++ dependencies with vcpkg, which needs
  # network access and cannot run in the Nix sandbox. The dependencies are
  # provided from nixpkgs instead: the cc wrapper picks up the include and
  # library paths of everything in buildInputs, so all that is left is to
  # satisfy the Makefile's hardcoded vcpkg paths with an empty triplet
  # directory. nixpkgs' CLI11 is header-only, so an empty archive stands in
  # for the -lCLI11 that vcpkg would have built.
  postPatch = ''
    mkdir -p vcpkg_installed/nix/include vcpkg_installed/nix/lib/manual-link
    $AR rcs vcpkg_installed/nix/lib/libCLI11.a
  '';

  # config.sh is a python script that generates _configuration.mk and the
  # per-configuration headers from a JSON description; use the default
  # configuration shipped with the repository.
  configurePhase = ''
    runHook preConfigure
    python3 config.sh champsim_config.json
    runHook postConfigure
  '';

  enableParallelBuilding = true;

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/champsim "$out/bin/champsim"
    install -Dm644 champsim_config.json "$out/share/champsim/champsim_config.json"
    runHook postInstall
  '';

  meta = {
    description = "Trace-based CPU cache and memory hierarchy simulator";
    homepage = "https://github.com/ChampSim/ChampSim";
    license = lib.licenses.asl20;
    mainProgram = "champsim";
    platforms = lib.platforms.unix;
  };
}
