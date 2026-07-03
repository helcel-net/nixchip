{
  fetchFromGitHub,
  abc-verifier,
  nix-update-script,
  version ? "unstable-2026-07-03",
  rev ? "bcfdf592289a408cd67ec19260f8a60a37b085b6",
  hash ? "sha256-gcuWvNPzQn4fJEalJaukyOl+FCh0MPxcTXI91l1foh4=",
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
