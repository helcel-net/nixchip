{
  lib,
  fetchFromGitHub,
  iverilog,
  nix-update-script,
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
  passthru = (old.passthru or { }) // { updateScript = nix-update-script { }; nixchipUpdate = true; nixchipCI = true; };
})
