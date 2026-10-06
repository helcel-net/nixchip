{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-10-06",
  rev ?
    if lib.hasPrefix "unstable-" version then "c15c6c05b175de17e81e6c4dd6175e07815add28" else version,
  hash ? "sha256-gpTGVe03sipQx4CiLEL4KBbx/EyUcvuwx1szb19CD0w=",
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
