{
  fetchFromGitHub,
  amaranth,
  lib,
  nix-update-script,
  version ? "unstable-2026-09-22",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "90449f1e6d5abdfb8cac7519ac7b34d83a9f42b7"
    else
      "refs/tags/v${version}",
  hash ? "sha256-6SZeRlxaF3sFVf0sv0p+jLqXc1sautiFwigXi5WE6Yo=",
  ...
}:

let
  # PDM's SCM hook rejects the nixchip "unstable-YYYY-MM-DD" version string
  # (not PEP 440).  Derive a compliant version: use the first segment if it's a
  # digit (historic N-unstable-... format), otherwise fall back to "0".
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
