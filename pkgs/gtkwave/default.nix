{
  fetchFromGitHub,
  gtkwave,
  nix-update-script,
  version ? "0-unstable-2026-06-25",
  rev ? "7d7b4db9e2f5485afe2aeeab0ad112f5b6a9b94b",
  hash ? "sha256-lEKW/OHk9xTqvf7UIcbZ3/toE6hWmed4dR/Ia21XY6I=",
  ...
}:

gtkwave.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "gtkwave";
    repo = "gtkwave";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "gtkwave";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
