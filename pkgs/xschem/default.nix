{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-11-10",
  rev ?
    if lib.hasPrefix "unstable-" version then "4b037ce1bd75307c1fa01d7f03098f0d1b79ec9b" else version,
  hash ? "sha256-LA+foDJUKvzjlVCqviwx8zvMulFbLGzcDdYPKJSQLjM=",
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
