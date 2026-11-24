{
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-11-24",
  rev ?
    if lib.hasPrefix "unstable-" version then "1d42dfcdf6cd91df7a59198477324c2ca78ba439" else version,
  hash ? "sha256-6c2KSFzIf0z2KsNlRWv3XU/8EbEZsUDrfyL6BDRBkUM=",
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
