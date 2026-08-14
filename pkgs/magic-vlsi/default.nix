{
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-08-11",
  rev ?
    if lib.hasPrefix "unstable-" version then "4432d7ec00ca744f5c9c3312662dece73ffbe83a" else version,
  hash ? "sha256-u1DYMMBTRGxLVdok/UR4OzCQFfZLRWDZQNMvX1mdb6U=",
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
