{
  lib,
  fetchFromGitHub,
  iverilog,
  nix-update-script,
  version ? "unstable-2026-11-18",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "0b15315c14177986b98fcad2940c0c3f98fdc8f9"
    else
      "v${lib.replaceStrings [ "." ] [ "_" ] version}",

  hash ? "sha256-gqEWu9Bf9r8hub2NAPT+A21MHEpWCCZwi06QQqcY9ac=",
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
