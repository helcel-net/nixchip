{
  fetchFromGitHub,
  cocotb,
  nix-update-script,
  version,
  rev,
  hash,
  ...
}:

cocotb.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "cocotb";
    repo = "cocotb";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "cocotb";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
