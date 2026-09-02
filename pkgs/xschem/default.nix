{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-09-02",
  rev ?
    if lib.hasPrefix "unstable-" version then "152351eb71d33ba8d6906ab9f389878426f84c2e" else version,
  hash ? "sha256-2rZKo7/Nc/8U6JsOAQmksOxaxRlF+IgittVWEyWy7lA=",
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
