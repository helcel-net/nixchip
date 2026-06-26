{
  fetchFromGitHub,
  openroad,
  nix-update-script,
  version ? "unstable-2026-06-25",
  rev ? "aea03d064484b0c48e7b385db1f8c3c9c634c6c6",
  hash ? "sha256-SLiTRnAHfjvH4gDAoB4J0UwKRJugz234Kqy9t3KpHdo=",
  patches ? [ ],
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
  inherit patches;
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "openroad";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
