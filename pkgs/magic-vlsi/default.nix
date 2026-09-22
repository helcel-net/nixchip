{
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-09-22",
  rev ?
    if lib.hasPrefix "unstable-" version then "4f53bb3091d1e4a9b2009a58f157a8a4331d4c84" else version,
  hash ? "sha256-nkbGWAoi2rAqn29naxenlJ65wY159NQYwGFg3AHt9f0=",
  ...
}:

magic-vlsi.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "RTimothyEdwards";
    repo = "magic";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script { };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
