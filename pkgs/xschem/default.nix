{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-09-29",
  rev ?
    if lib.hasPrefix "unstable-" version then "125da79c9f480638daafb2797e55b1d3e4125ce4" else version,
  hash ? "sha256-hoLGqZ6vjbir25pEsf2ft011/CMAycUdiHt1/sodnBI=",
  ...
}:

xschem.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "StefanSchippers";
    repo = "xschem";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "xschem";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
