{
  fetchFromGitHub,
  edalize,
  lib,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "f8f66da85ca99a2eb1e8acd29cb0ec8718896699"
    else
      "refs/tags/v${version}",
  hash ? "sha256-z4duSUfSeZYiQI3Mq6OE0XmFAS0m3+cI9mvbxQ6LlVk=",
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
