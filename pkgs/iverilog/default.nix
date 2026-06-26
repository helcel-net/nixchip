{
  lib,
  fetchFromGitHub,
  iverilog,
  nix-update-script,
  version ? "unstable-2026-05-05",
  rev ? if lib.hasPrefix "unstable-" version then "8c7f8f3f7ba5d843f9da5867207afc70b7224674" else "v${lib.replaceStrings [ "." ] [ "_" ] version}",
 
  hash ? "sha256-S9MnR+ymmZzNKjW8YTnN09fWJ0wjLv/M4d/uppAYC7I=",
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
