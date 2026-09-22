{
  lib,
  fetchFromGitHub,
  iverilog,
  nix-update-script,
  version ? "unstable-2026-09-22",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "d1982fc7d823f1786f4788a88551f0664c16d7e7"
    else
      "v${lib.replaceStrings [ "." ] [ "_" ] version}",

  hash ? "sha256-JXC2EjWVgdz/BCcEU9gXlZPdVtHZaGKA83cT2hRVisk=",
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
