{
  fetchFromGitHub,
  abc-verifier,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ? "b4ca3e7f520fcb8f21553f20b7fd6dec8321490d",
  hash ? "sha256-rMWqDRdJt6SeQh4QMzJzeYaerxBZqEJfoCI1kmFj7A4=",
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
