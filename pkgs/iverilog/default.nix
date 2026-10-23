{
  lib,
  fetchFromGitHub,
  iverilog,
  nix-update-script,
  version ? "unstable-2026-10-23",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "1a663cb33a9d8e70f6f3f5e9077120c60dcb6e06"
    else
      "v${lib.replaceStrings [ "." ] [ "_" ] version}",

  hash ? "sha256-0y0GLEhouI4uEIMTe/LAOuW7fVnmvom64ZDQ9m6bmoA=",
  ...
}:

iverilog.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "steveicarus";
    repo = "iverilog";
    inherit rev hash;
  };
  doInstallCheck = false;
  env = (old.env or { }) // {
    NIX_CFLAGS_COMPILE = "${old.env.NIX_CFLAGS_COMPILE or ""} -Wno-error=format-security";
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script { };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
