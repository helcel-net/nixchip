{
  fetchFromGitHub,
  yosys,
  nix-update-script,
  version ? "0.62",
  hash ? "sha256-FzvdjdAURB5iCkGwsYY6A2wP/Je/IW4AOd4kVOEOeVc=",
}:

yosys.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "YosysHQ";
    repo = "yosys";
    tag = "v${version}";
    fetchSubmodules = true;
    inherit hash;
  };
  passthru = (old.passthru or { }) // { updateScript = nix-update-script { }; nixchipUpdate = true; nixchipCI = true; };
})
