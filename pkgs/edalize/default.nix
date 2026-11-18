{
  fetchFromGitHub,
  edalize,
  lib,
  nix-update-script,
  version ? "unstable-2026-11-17",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "d76f10d2dbd37c18119bf260c7bfc2c1f3e8eb40"
    else
      "refs/tags/v${version}",
  hash ? "sha256-AbxXzdddbpCoG+tSQDSFDsX1W67ypTUFVFJfCragCZ0=",
  ...
}:

let
  # setuptools_scm rejects the nixchip "unstable-YYYY-MM-DD" version string.
  # Use the first segment if it's a digit, otherwise fall back to "0".
  # Release slots build from a tag, so their version already is PEP 440 -- and
  # their rev is a "refs/tags/..." string that must not leak into it.
  pep440Version =
    let
      rawTag = builtins.elemAt (lib.splitString "-" version) 0;
      tag = if builtins.match "[0-9].*" rawTag != null then rawTag else "0";
      shortRev = lib.substring 0 7 rev;
    in
    if lib.hasPrefix "unstable-" version then "${tag}1.dev1+g${shortRev}" else version;
in
edalize.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "olofk";
    repo = "edalize";
    inherit rev hash;
  };
  preBuild = (old.preBuild or "") + ''
    export SETUPTOOLS_SCM_PRETEND_VERSION="${pep440Version}"
  '';
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "edalize";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
