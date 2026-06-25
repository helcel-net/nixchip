{
  fetchFromGitHub,
  amaranth,
  nix-update-script,
  version,
  rev,
  hash,
  ...
}:

amaranth.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "amaranth-lang";
    repo = "amaranth";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "amaranth";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
