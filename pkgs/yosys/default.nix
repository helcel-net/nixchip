{
  fetchFromGitHub,
  yosys,
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
})
