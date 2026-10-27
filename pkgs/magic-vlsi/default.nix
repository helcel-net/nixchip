{
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-10-27",
  rev ?
    if lib.hasPrefix "unstable-" version then "eeaa1f41f27b9ad24619465b3587a0a63f629c97" else version,
  hash ? "sha256-sQD3h9QIBimERhz54bJVDbSSWN8rJGqNbYv9pAMsBkc=",
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
