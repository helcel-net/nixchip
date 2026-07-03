{
  fetchFromGitHub,
  edalize,
  lib,
  nix-update-script,
  version ? "unstable-2026-07-02",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "7e5f16f7a3c29b3ae744e1f19fa6ea67530edd70"
    else
      "refs/tags/v${version}",
  hash ? "sha256-sxCq8f/whY//Il91dk56Eg2FrHaJFVYekMtGfUJu0C8=",
  ...
}:

let
  # setuptools_scm rejects the nixchip "unstable-YYYY-MM-DD" version string.
  # Use the first segment if it's a digit, otherwise fall back to "0".
  pep440Version =
    let
      rawTag = builtins.elemAt (lib.splitString "-" version) 0;
      tag = if builtins.match "[0-9].*" rawTag != null then rawTag else "0";
      shortRev = lib.substring 0 7 rev;
    in
    "${tag}1.dev1+g${shortRev}";
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
