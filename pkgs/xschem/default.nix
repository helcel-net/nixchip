{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-11-03",
  rev ?
    if lib.hasPrefix "unstable-" version then "9c722b798d0ebe26101b3e5c951519bff48c31b3" else version,
  hash ? "sha256-dAGs/y6gSMabgTaIN3I5sD76+kZNBBTLpjL0lVXpQTE=",
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
