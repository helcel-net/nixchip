{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  python3,
  gitMinimal,
  nix-update-script,
  cargoLockFile ? ./Cargo.lock,
  version ? "unstable-2026-06-18",
  rev ? "4ff8b6b843ed240fb3cb268f489a25e33bd6af98",
  hash ? "sha256-wCaLCMbjhU8Hb7gNjMzslOU50CFF45/Gtx7yq9I5+3k=",
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

  postPatch = ''
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
    license = with lib.licenses; [ asl20 mit ];
    mainProgram = "bender";
    platforms = lib.platforms.all;
  };
})
