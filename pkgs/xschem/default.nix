{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-09-15",
  rev ?
    if lib.hasPrefix "unstable-" version then "c64b2096b94ef44f07976df2b8f4af66180ef343" else version,
  hash ? "sha256-PN6H2hW1zvbSjgqMl9gSYrXfOamEmqMZoUCf664Eb64=",
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
