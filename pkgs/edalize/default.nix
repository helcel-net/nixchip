{
  fetchFromGitHub,
  edalize,
  lib,
  nix-update-script,
  version ? "unstable-2026-09-01",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "7014995f85728b48487290cb2f650f0bdbe620a4"
    else
      "refs/tags/v${version}",
  hash ? "sha256-T9Q74o2VA/CtwJK5ZY3KucZco1i6uEUTo50bzCl1oCc=",
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
