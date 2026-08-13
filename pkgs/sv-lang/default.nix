{
  fetchFromGitHub,
  sv_lang,
  lib,
  tomlplusplus,
  nix-update-script,
  version ? "11.0-unstable-2026-08-12",
  rev ? "e3291f8fe002c22d625732b928877b73688d8e07",
  hash ? "sha256-xYJytN9ISG5kk0/fB1hg/buAG4h9zd4/Q+L53L9Lo6U=",
  ...
}:

let
  # nixpkgs' fmt_12 is 12.1.0; newer slang requires >= 12.2 via
  # FIND_PACKAGE_ARGS, so FetchContent would fall back to a network git clone
  # that fails in the Nix sandbox. Vendor the exact tag slang asks for and
  # point FetchContent at it directly instead.
  fmt = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    tag = "12.2.0";
    hash = "sha256-Tc7PmNxUv7ajw6GaHPGEEtrD/fl6is7RB8TPestJa1o=";
  };
in
sv_lang.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "MikePopoloski";
    repo = "slang";
    inherit rev hash;
  };
  postPatch = (old.postPatch or "") + ''
    substituteInPlace external/CMakeLists.txt \
      --replace-fail "GIT_REPOSITORY https://github.com/fmtlib/fmt.git" "SOURCE_DIR ${fmt}" \
      --replace-fail "GIT_TAG 12.2.0" "" \
      --replace-fail "GIT_SHALLOW ON" ""
  '';
  # nixpkgs sv-lang 9.1 didn't use tomlplusplus; newer slang fetches it via
  # FetchContent with FIND_PACKAGE_ARGS 3.4, which requires it in buildInputs.
  buildInputs = (old.buildInputs or [ ]) ++ [ tomlplusplus ];
  # nixpkgs catch2_3 is 3.14; newer slang requires ≥ 3.15 via FIND_PACKAGE_ARGS,
  # so FetchContent falls back to a network clone which fails in the Nix sandbox.
  # Disable tests entirely to avoid the catch2 dependency.
  doCheck = false;
  cmakeFlags = (lib.remove "-DSLANG_INCLUDE_TESTS=ON" (old.cmakeFlags or [ ])) ++ [
    "-DSLANG_INCLUDE_TESTS=OFF"
  ];
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "sv-lang";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
