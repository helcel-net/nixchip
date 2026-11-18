{
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-11-17",
  rev ?
    if lib.hasPrefix "unstable-" version then "2c6d97b2f21003fa1778d5658eb02b32724399ab" else version,
  hash ? "sha256-aHmFEBBvpdd9jG3BWyCSRFFiJe31ZC6CVMAGdJjp3Pc=",
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
