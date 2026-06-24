{
  lib,
  fetchFromGitHub,
  iverilog,
  version ? "13.0",
  hash ? "sha256-SfODx7K3UrDHMoKCbMFpxo4t9j9vG1oWF0RFS3dSUm4=",
}:

iverilog.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "steveicarus";
    repo = "iverilog";
    tag = "v${lib.replaceStrings [ "." ] [ "_" ] version}";
    inherit hash;
  };
})
