{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-10-23",
  rev ?
    if lib.hasPrefix "unstable-" version then "36e0eab33b0c7e02e6f99c54b0a39d42231039fb" else version,
  hash ? "sha256-ADqf3sMNnKvK3ZttnGbP2RSP05pzoSUskW7IvQIX3c8=",
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
