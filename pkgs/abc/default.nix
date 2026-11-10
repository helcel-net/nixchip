{
  fetchFromGitHub,
  abc-verifier,
  nix-update-script,
  version ? "unstable-2026-11-10",
  rev ? "25d4ee221b2a9ab5124f3a222bcdf6f922d3d8a3",
  hash ? "sha256-ylrhZtRRCeK2tOJUq76SQLZgfbVMybLiDCeOo1P9Qu8=",
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
