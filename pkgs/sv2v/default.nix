{
  fetchFromGitHub,
  haskellPackages,
  nix-update-script,
  version ? "unstable-2026-06-25",
  rev ? "6662fa5da71f87797598060f17728b284b99a9fc",
  hash ? "sha256-ziwLw1/S4wbnqml/AnN/yerOJJ3VOfRc3dZa8cmEaD0=",
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
