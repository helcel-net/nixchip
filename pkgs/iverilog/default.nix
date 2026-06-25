{
  lib,
  fetchFromGitHub,
  iverilog,
  nix-update-script,
  version,
  hash,
  ...
}:

iverilog.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "steveicarus";
    repo = "iverilog";
    tag = "v${lib.replaceStrings [ "." ] [ "_" ] version}";
    inherit hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script { };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
