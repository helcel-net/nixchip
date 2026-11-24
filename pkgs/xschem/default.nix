{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-11-24",
  rev ?
    if lib.hasPrefix "unstable-" version then "4d38c64de0cce3e78e1b38d2e3afc62c7071ff78" else version,
  hash ? "sha256-/Cs4yEPiU8fPz3MoN51BjRdjoEBJzrGelXmL6fwe/tM=",
  ...
}:

xschem.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "StefanSchippers";
    repo = "xschem";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "xschem";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
