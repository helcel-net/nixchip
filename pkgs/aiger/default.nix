{
  lib,
  fetchFromGitHub,
  aiger,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "039ec1a2cc37d3093ac35c4b6df65336b346f409"
    else
      "refs/tags/rel-${version}",
  hash ? "sha256-evW5QSdXnT5rgxCRBYnvrE2zUAu/ZuH4Y2jHznXNAn4=",
  ...
}:

aiger.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "arminbiere";
    repo = "aiger";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "aiger";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
