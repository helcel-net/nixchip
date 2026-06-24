{
  fetchFromGitHub,
  openroad,
  version ? "26Q2",
  hash ? "sha256-dB9PfPlp6vZ9+Th8LJE65BW9YeuUL0G4JtjzQxg6UpQ=",
}:

openroad.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "The-OpenROAD-Project";
    repo = "OpenROAD";
    tag = version;
    fetchSubmodules = true;
    inherit hash;
  };
})
