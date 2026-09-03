{
  fetchFromGitHub,
  sv_lang,
  lib,
  tomlplusplus,
  nix-update-script,
  version ? "unstable-2026-09-02",
  rev ? "cbd5d62d86fc7c5f191fb09491c7d894281f1f99",
  hash ? "sha256-NNUWbtGiSFtVlxoyRYxR8K2HO6Dp9CgHYcR+Mvucdu0=",
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

  # Same story for mimalloc: slang wants >= 3.4 (FIND_PACKAGE_ARGS 3.4) and
  # nixpkgs' is older, so FetchContent would clone. Vendor the pinned tag.
  mimalloc = fetchFromGitHub {
    owner = "microsoft";
    repo = "mimalloc";
    tag = "v3.5.0";
    hash = "sha256-1cHcEjcnzyJaEohtMoC3h7EdXSLE1lHCnq8kURXIx/E=";
  };
in
sv_lang.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "MikePopoloski";
    repo = "slang";
    inherit rev hash;
    # .git_archival.txt is export-subst, so GitHub rewrites it per archive and
    # the hash of a pinned rev drifts as refs move. Fetch over git instead.
    forceFetchGit = true;
  };
  # nixpkgs sv-lang 9.1 didn't use tomlplusplus; newer slang fetches it via
  # FetchContent with FIND_PACKAGE_ARGS 3.4, which requires it in buildInputs.
  buildInputs = (old.buildInputs or [ ]) ++ [ tomlplusplus ];
  # nixpkgs catch2_3 is 3.14; newer slang requires ≥ 3.15 via FIND_PACKAGE_ARGS,
  # so FetchContent falls back to a network clone which fails in the Nix sandbox.
  # Disable tests entirely to avoid the catch2 dependency.
  doCheck = false;
  cmakeFlags = (lib.remove "-DSLANG_INCLUDE_TESTS=ON" (old.cmakeFlags or [ ])) ++ [
    "-DSLANG_INCLUDE_TESTS=OFF"
    # Newer slang defaults to a vendored boost_unordered plus a FetchContent'd
    # boost::regex; use nixpkgs' boost (already in buildInputs) instead so
    # nothing needs the network.
    "-DSLANG_USE_SYSTEM_BOOST=ON"
    # Point FetchContent at the vendored trees instead of patching upstream's
    # fetch URLs (the URL prefix variable keeps getting renamed); cmake's
    # FETCHCONTENT_SOURCE_DIR_<NAME> overrides work regardless.
    "-DFETCHCONTENT_SOURCE_DIR_FMT=${fmt}"
    "-DFETCHCONTENT_SOURCE_DIR_MIMALLOC=${mimalloc}"
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
