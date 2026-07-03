{ 
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-07-03",
  rev ? if lib.hasPrefix "unstable-" version then "2f23be9dc3c5b323821ffe91cf2adf1943b29b1a" else version,
  hash ? "sha256-kPmGRWa+NqVhDdhE2GcvdiDPvpzyxsPL9kaK+Bbap3M=",
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
