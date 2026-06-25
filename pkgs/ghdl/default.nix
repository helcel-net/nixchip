{
  fetchFromGitHub,
  ghdl,
  nix-update-script,
  version,
  rev,
  hash,
  ...
}:

ghdl.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "ghdl";
    repo = "ghdl";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "ghdl";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
