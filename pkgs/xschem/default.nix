{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-10-27",
  rev ?
    if lib.hasPrefix "unstable-" version then "3c76b5dfb409640db38c418345820775d8a63ed9" else version,
  hash ? "sha256-0wfqSqHguHYVAlS8zfYq8yfxknoaHM/3W9LZrY8VzlU=",
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
