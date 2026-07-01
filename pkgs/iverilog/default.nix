{
  lib,
  fetchFromGitHub,
  iverilog,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ? if lib.hasPrefix "unstable-" version then "5a99d0e449468630f8386d5488e9f70bbaf3bbf5" else "v${lib.replaceStrings [ "." ] [ "_" ] version}",
 
  hash ? "sha256-MeaJzd35h1wcBEwJ8HNCQwsc2xyMY2jJZwOSznLvDfI=",
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
