{
  fetchFromGitHub,
  abc-verifier,
  nix-update-script,
  version ? "unstable-2026-11-24",
  rev ? "bd23a971519f70b1a8dbb8d0a2c0574eeb69af69",
  hash ? "sha256-BIJJKA/1ytX4He6KqSNoMxzDaXGspwfaZm+REL+j/p0=",
  ...
}:

abc-verifier.overrideAttrs (old: {
  inherit version;
  # Upstream turned large static buffers thread-local, which overflows
  # R_X86_64_DTPOFF32 relocations at link; they ship this opt-out for it.
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DABC_USE_NO_THREAD_LOCAL=ON" ];
  src = fetchFromGitHub {
    owner = "berkeley-abc";
    repo = "abc";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "abc";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
