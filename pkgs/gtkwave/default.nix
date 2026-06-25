{
  fetchFromGitHub,
  gtkwave,
  nix-update-script,
  version,
  rev,
  hash,
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
