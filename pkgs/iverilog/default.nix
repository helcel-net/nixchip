{
  lib,
  fetchFromGitHub,
  iverilog,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ? if lib.hasPrefix "unstable-" version then "a1c333ea6e0d32a7e2655dc5bf5d354d0f03970e" else "v${lib.replaceStrings [ "." ] [ "_" ] version}",
 
  hash ? "sha256-+Y5GiUePyZ/UGYMpjmvi5UB7Gph3cpWTE1SRGrBRQfE=",
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
