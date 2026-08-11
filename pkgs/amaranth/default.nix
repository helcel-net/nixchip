{
  fetchFromGitHub,
  amaranth,
  lib,
  nix-update-script,
  version ? "unstable-2026-08-11",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "fe524a11936222b2dd08751c68c66ef4b6d0bd22"
    else
      "refs/tags/v${version}",
  hash ? "sha256-menBc9OgGGOBNhOJHEMZ/Ct0zR74Qd59R/fs2rWDrrg=",
  ...
}:

let
  # PDM's SCM hook rejects the nixchip "unstable-YYYY-MM-DD" version string
  # (not PEP 440).  Derive a compliant version: use the first segment if it's a
  # digit (historic N-unstable-... format), otherwise fall back to "0".
  pep440Version =
    let
      rawTag = builtins.elemAt (lib.splitString "-" version) 0;
      tag = if builtins.match "[0-9].*" rawTag != null then rawTag else "0";
      shortRev = lib.substring 0 7 rev;
    in
    "${tag}1.dev1+g${shortRev}";
in
amaranth.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "amaranth-lang";
    repo = "amaranth";
    inherit rev hash;
  };
  preBuild = (old.preBuild or "") + ''
    export PDM_BUILD_SCM_VERSION="${pep440Version}"
  '';
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "amaranth";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
