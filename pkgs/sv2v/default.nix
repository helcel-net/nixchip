{
  fetchFromGitHub,
  haskell,
  sv2v,
  nix-update-script,
  version,
  rev,
  hash,
  ...
}:

haskell.lib.overrideCabal sv2v (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "zachjs";
    repo = "sv2v";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "sv2v";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
