{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-08-11",
  rev ?
    if lib.hasPrefix "unstable-" version then "8869a957ccad366b07bb0eb25ce60aa26aff6261" else version,
  hash ? "sha256-ak6VVjcpN4ecIz7xLEI6ohWy0ZOU1Pfr68hXNisOMV8=",
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
