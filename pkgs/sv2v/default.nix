{
  fetchFromGitHub,
  haskellPackages,
  nix-update-script,
  version,
  rev,
  hash,
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
