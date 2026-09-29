{
  fetchFromGitHub,
  abc-verifier,
  nix-update-script,
  version ? "unstable-2026-09-29",
  rev ? "ab2139ee0c418f54136deb4e8e89eeea3b87efc8",
  hash ? "sha256-dPTD3cO4YS/kt2Lr79d0m7Q8m2OngWmLRAHLS3JILco=",
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
