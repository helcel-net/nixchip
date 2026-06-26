{
  fetchFromGitHub,
  amaranth,
  lib,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ? "c9be3e4a9e932c25e361d0085af31c5b420efc41",
  hash ? "sha256-0UfGuvfJTbF9enn6bb+75nKjLxsagQjnTL3UVKjqY+o=",
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
