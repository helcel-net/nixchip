{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-09-22",
  rev ?
    if lib.hasPrefix "unstable-" version then "ddc734480d5326fb787993dad24f4062e5d28434" else version,
  hash ? "sha256-rMKDhMZ+17EJ+lOvXLFkbK0dY+9C5AvW1x1o3C0A3SQ=",
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
