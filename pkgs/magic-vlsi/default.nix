{ 
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-05-05",
  rev ? if lib.hasPrefix "unstable-" version then "428dbeb35d1059e82823cd8556530bab578f1084" else "v${version}",
  hash  ? "sha256-sr7H2vBOTAA59d3itVNqRVy1fR/83ZrTGl5s4I+g0Tw=",
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
