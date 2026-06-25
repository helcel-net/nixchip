{
  fetchFromGitHub,
  aiger,
  nix-update-script,
  version,
  rev,
  hash,
  ...
}:

aiger.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "arminbiere";
    repo = "aiger";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "aiger";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
