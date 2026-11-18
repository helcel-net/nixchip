{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-11-17",
  rev ?
    if lib.hasPrefix "unstable-" version then "5ed6228bcfbb47b50530ef4a3c90709c63c7657d" else version,
  hash ? "sha256-LpTaA+HR5+rFs3taomELGQZ1VCO0RxK7eExYPcgD/iM=",
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
