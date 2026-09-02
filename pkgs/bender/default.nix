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
  # derived from them.
  env = {
    SLANG_SRC_DIR = "${slang}";
    FMT_SRC_DIR = "${fmt}";
    MIMALLOC_SRC_DIR = "${mimalloc}";
  };

  # The 0.32.0 release predates those env vars: it hardcodes the FetchContent
  # git URLs and derives the include paths from cmake's _deps tree, so the
  # pre-fetched sources have to be substituted in by hand there.
  postPatch = ''
    if ! grep -q SLANG_SRC_DIR crates/bender-slang/build.rs; then
      cp -r ${slang} slang-src
      chmod -R +w slang-src
      cp -r ${fmt} fmt-src
      chmod -R +w fmt-src
      substituteInPlace crates/bender-slang/CMakeLists.txt \
        --replace-fail "GIT_REPOSITORY https://github.com/MikePopoloski/slang.git" "SOURCE_DIR $PWD/slang-src" \
        --replace-fail "GIT_TAG        v11.0" "" \
        --replace-fail "GIT_SHALLOW    TRUE" ""
      substituteInPlace slang-src/external/CMakeLists.txt \
        --replace-fail "GIT_REPOSITORY https://github.com/fmtlib/fmt.git" "SOURCE_DIR ${fmt}" \
        --replace-fail "GIT_TAG 12.1.0" "" \
        --replace-fail "GIT_SHALLOW ON" "" \
        --replace-fail "GIT_REPOSITORY https://github.com/microsoft/mimalloc.git" "SOURCE_DIR ${mimalloc}" \
        --replace-fail "GIT_TAG v3.3.2" ""
      substituteInPlace crates/bender-slang/build.rs \
        --replace-fail 'let slang_include_dir = dst.join("build/_deps/slang-src/include");' 'let slang_include_dir = manifest_dir.join("../../slang-src/include");' \
        --replace-fail 'let fmt_include_dir = dst.join("build/_deps/fmt-src/include");' 'let fmt_include_dir = manifest_dir.join("../../fmt-src/include");'
    fi
  '';

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
