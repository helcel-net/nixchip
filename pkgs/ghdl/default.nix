{
  fetchFromGitHub,
  ghdl,
  nix-update-script,
  version ? "6.0.0",
  hash ? "sha256-Q5lAWMa1SFjoIJTdWlHSbS4Cg5RYWiej8F05Xrz9ArY=",
  ...
}:

ghdl.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "ghdl";
    repo = "ghdl";
    tag = "v${version}";
    inherit hash;
  };
  passthru = (old.passthru or { }) // { updateScript = nix-update-script { }; nixchipUpdate = true; nixchipCI = true; };
})
