{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-08-18",
  rev ?
    if lib.hasPrefix "unstable-" version then "5d5a4adbfd36a34e4c23396932d21692a38ca17c" else version,
  hash ? "sha256-J94obFoXoWE6kBC+s9xHIcB8FqPGvsZK7U2g5IvJJgA=",
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
