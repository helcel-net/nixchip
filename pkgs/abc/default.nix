{
  fetchFromGitHub,
  abc-verifier,
  nix-update-script,
  version ? "unstable-2026-09-01",
  rev ? "c6e8823c0b9f0c7c469a7538dc2a75b39da17cc4",
  hash ? "sha256-3jCuVtCP1Zy48E4ARUpGXAlI8ZKCmM++0XLck3zI8k4=",
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
