{
  fetchFromGitHub,
  yosys,
  nix-update-script,
  version,
  rev,
  hash,
  ...
}:

yosys.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "YosysHQ";
    repo = "yosys";
    fetchSubmodules = true;
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script { };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
