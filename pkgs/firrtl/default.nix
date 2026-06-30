{
  lib,
  fetchFromGitHub,
  firrtl,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "64731bbb16142a2b09ccbe74ab41b76b7a265869"
    else
      "v${version}",
  hash ? "sha256-djy81G2OGW/r0fGfluUa7+jL/6usD3Q015kuuH6DUE0=",
  ...
}:

firrtl.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "chipsalliance";
    repo = "firrtl";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "firrtl";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
