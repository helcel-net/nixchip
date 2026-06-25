{
  fetchFromGitHub,
  openroad,
  nix-update-script,
  version ? "2021_03_09_stable-unstable-2026-06-25",
  rev ? "c6efacca3ee033a10bfc0a32202c103354f0804b",
  hash ? "sha256-SLiTRnAHfjvH4gDPoB4J0UwKRJugz234Kqy9t3KpHdo=",
  ...
}:
openroad.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "The-OpenROAD-Project";
    repo = "OpenROAD";
    fetchSubmodules = true;
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "openroad";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
