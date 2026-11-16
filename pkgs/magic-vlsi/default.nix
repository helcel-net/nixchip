{
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-11-10",
  rev ?
    if lib.hasPrefix "unstable-" version then "0cdada32138a376f3b0339ef4753b1f2f47d7f09" else version,
  hash ? "sha256-YFXBVMqzvyy1ljjCc18zSRnS03Yseh+xcbPOgHwv52o=",
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
