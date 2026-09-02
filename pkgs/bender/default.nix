{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  python3,
  gitMinimal,
  nix-update-script,
  cargoLockFile ? ./Cargo.lock,
  version ? "unstable-2026-09-01",
  rev ? "97b599b2d3cb433d204cf71b8583f6ec2825d509",
  hash ? "sha256-TzjfVOQAQ5osp3CpgPJ5TiWX7cWZZiM7La2n/0rNZuA=",
}:

let
  slang = fetchFromGitHub {
    owner = "MikePopoloski";
    repo = "slang";
    tag = "v11.0";
    hash = "sha256-popHzwX0qwv2POAl7/qX3e//OwJRXGtSl9xogpSn2LI=";
  };

  fmt = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    tag = "12.1.0";
    hash = "sha256-ZmI1Dv0ZabPlxa02OpERI47jp7zFfjpeWCy1WyuPYZ0=";
  };

  mimalloc = fetchFromGitHub {
    owner = "microsoft";
    repo = "mimalloc";
    tag = "v3.3.2";
    hash = "sha256-GZ37qQVDe9jgMb4Coe5oKvgaLTspZDlSkS5rdy1MfUU=";
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "bender";
  inherit version rev;

  src = fetchFromGitHub {
    owner = "pulp-platform";
    repo = "bender";
    inherit (finalAttrs) rev;
    inherit hash;
  };

  cargoLock = {
    lockFile = cargoLockFile;
  };

  # Upstream's build.rs supports SLANG_SRC_DIR / FMT_SRC_DIR /
  # MIMALLOC_SRC_DIR precisely for sandboxed builds: they become
  # FETCHCONTENT_SOURCE_DIR_* cmake defines (the fmt/mimalloc overrides also
  # reach slang's own nested FetchContent calls), and the include paths are
  # derived from them. No source patching needed any more.
  env = {
    SLANG_SRC_DIR = "${slang}";
    FMT_SRC_DIR = "${fmt}";
    MIMALLOC_SRC_DIR = "${mimalloc}";
  };

  nativeBuildInputs = [
    cmake
    python3
  ];
  nativeCheckInputs = [ gitMinimal ];
  doCheck = false;

  passthru = {
    updateScript = nix-update-script { };
    nixchipUpdate = true;
    nixchipCI = true;
  };

  meta = {
    description = "Dependency management tool for hardware projects";
    homepage = "https://github.com/pulp-platform/bender";
    license = with lib.licenses; [
      asl20
      mit
    ];
    mainProgram = "bender";
    platforms = lib.platforms.all;
  };
})
