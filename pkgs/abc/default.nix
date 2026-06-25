{
  fetchFromGitHub,
  abc-verifier,
  nix-update-script,
  version ? "0-unstable-2026-06-25",
  rev ? "3ce53c361f6017153a0f9bb3c91f4d04eb820fc2",
  hash ? "sha256-9Sldy42mAfalA9Jqa752BCOTh+rtvu8nFeh1Nt0rJDk=",
  ...
}:

abc-verifier.overrideAttrs (old: {
  inherit version;
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
