{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-11-18",
  rev ?
    if lib.hasPrefix "unstable-" version then "4d81c7b5689ca230c507eb19dd46f3a2a6a5d607" else version,
  hash ? "sha256-5/BGndF5s9n7nmQ7GD9lccjWxJSahb91VRWOJT5F8Yc=",
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
