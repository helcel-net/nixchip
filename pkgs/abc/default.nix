{
  fetchFromGitHub,
  abc-verifier,
  nix-update-script,
  version ? "unstable-2026-09-15",
  rev ? "35c3375757115622d5e1d83e3a998e37a4432241",
  hash ? "sha256-8qJ00MrcjF1PY607bLHzyudm1Z0bAKkb1/HEFM99YZc=",
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
