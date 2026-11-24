{
  lib,
  fetchFromGitHub,
  iverilog,
  nix-update-script,
  version ? "unstable-2026-11-24",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "9b131db4af34619efe977c4617a7b15c4cc5deb6"
    else
      "v${lib.replaceStrings [ "." ] [ "_" ] version}",

  hash ? "sha256-qLgUFbe+B7Vfpj96OrPvWCgAlKcRefssPLu+OEgEbYo=",
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
