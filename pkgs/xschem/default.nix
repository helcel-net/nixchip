{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-09-01",
  rev ?
    if lib.hasPrefix "unstable-" version then "cfbeaf069db7c8872e501ad7963fcc291d83d944" else version,
  hash ? "sha256-AtZHnmCvkp5TwQz5hPRYRqp5noQxJmF5fncMV3TMyCw=",
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
