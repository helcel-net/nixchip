{
  fetchFromGitHub,
  edalize,
  lib,
  nix-update-script,
  version,
  rev,
  hash,
  ...
}:

let
  # setuptools_scm rejects the nixchip "0-unstable-YYYY-MM-DD" version string.
  pep440Version =
    let
      tag = builtins.elemAt (lib.splitString "-" version) 0;
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
