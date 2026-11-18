{
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-11-18",
  rev ?
    if lib.hasPrefix "unstable-" version then "4205ad22bf919cc183af997b60c21140fd6d6fa9" else version,
  hash ? "sha256-jOc6UpGYqj+UJkvaJ6DdYQnaB6CQrkieV1nGk23yD7Q=",
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
