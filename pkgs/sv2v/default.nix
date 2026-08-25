{
  fetchFromGitHub,
  haskellPackages,
  nix-update-script,
  version ? "unstable-2026-08-25",
  rev ? "493a88f930802da68f592c192ec86991eaf95c49",
  hash ? "sha256-emqu56lC2W4s0eoxEn3pi2b4mrCsjW9AF/gG9DX4ZOs=",
  ...
}:

haskellPackages.sv2v.overrideAttrs (_: {
  inherit version;
  src = fetchFromGitHub {
    owner = "zachjs";
    repo = "sv2v";
    inherit rev hash;
  };
  passthru = {
    updateScript = nix-update-script {
      attrPath = "sv2v";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
