{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-11-20",
  rev ?
    if lib.hasPrefix "unstable-" version then "f3b51b3b2e1701eba6c96c8820dd56a19b40244a" else version,
  hash ? "sha256-I7OdPhfSiEhLMeiFtZ8ut5tpAGVvLD0CFDm/UJUpPwY=",
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
