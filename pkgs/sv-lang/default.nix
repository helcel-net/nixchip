{
  fetchFromGitHub,
  sv_lang,
  lib,
  tomlplusplus,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ? "88c0826084519c93acacd5f681a647b77f1f0b81",
  hash ? "sha256-xnGSFN4S48vs3Y+BYvt2zUsf1MumTyikA9sAtqmq10s=",
  ...
}:

sv_lang.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "MikePopoloski";
    repo = "slang";
    inherit rev hash;
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
