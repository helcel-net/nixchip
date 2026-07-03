{
  lib,
  fetchFromGitHub,
  iverilog,
  nix-update-script,
  version ? "unstable-2026-07-03",
  rev ? if lib.hasPrefix "unstable-" version then "98d10727f27b042ae44ce03ae62df5ad97744542" else "v${lib.replaceStrings [ "." ] [ "_" ] version}",
 
  hash ? "sha256-wERygTIBSAVJ0As6f8f6qiNxCxdxzStYYMxwAN0flvw=",
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
