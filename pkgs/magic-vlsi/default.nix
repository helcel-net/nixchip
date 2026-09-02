{
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-09-02",
  rev ?
    if lib.hasPrefix "unstable-" version then "4481c509dae88e96c3af51f45bc3545ec6af7f60" else version,
  hash ? "sha256-m6q5OGal1NPqfGHYHUNIlYnWdsVKLkaYVbxcplvqJi8=",
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
