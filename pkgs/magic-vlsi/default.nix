{
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-11-03",
  rev ?
    if lib.hasPrefix "unstable-" version then "d914f66693e6ce0bd30dc1f2b265c2bcd7b20762" else version,
  hash ? "sha256-gvS0mSeyRU5lktJryQOUSPbsQibOPGzPYYg1PJTm7BM=",
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
