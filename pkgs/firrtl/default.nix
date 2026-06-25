{
  fetchFromGitHub,
  firrtl,
  nix-update-script,
  version ? "0-unstable-2026-06-25",
  rev ? "64731bbb16142a2b09ccbe74ab41b76b7a265869",
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
