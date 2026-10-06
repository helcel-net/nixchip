{
  lib,
  fetchFromGitHub,
  iverilog,
  nix-update-script,
  version ? "unstable-2026-10-06",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "467d830d2435d28d63ecdfc011c5bf150f15f206"
    else
      "v${lib.replaceStrings [ "." ] [ "_" ] version}",

  hash ? "sha256-FGZ/l1yJNQcVktO5VwYhvZcCX3UX7Go1QZzLGxeqjuk=",
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
