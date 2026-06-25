{
  fetchFromGitHub,
  firrtl,
  nix-update-script,
  version,
  rev,
  hash,
  ...
}:

firrtl.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "chipsalliance";
    repo = "firrtl";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "firrtl";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
