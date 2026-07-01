{
  fetchFromGitHub,
  abc-verifier,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ? "a01df4b82cb4ff6847296d69891f87f95af52c67",
  hash ? "sha256-6L5mRaUdF/aoV/7FyIdyHt7/njWp9C19U3bTw/ZwQFs=",
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
