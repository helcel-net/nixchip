{
  fetchFromGitHub,
  amaranth,
  lib,
  nix-update-script,
  version,
  rev,
  hash,
  ...
}:

let
  # PDM's SCM hook rejects the nixchip "0-unstable-YYYY-MM-DD" version string
  # (not PEP 440).  Derive a compliant version following the same pattern that
  # nixpkgs uses for amaranth-boards: strip the tag prefix, append ".dev1+g<rev>".
  pep440Version =
    let
      tag = builtins.elemAt (lib.splitString "-" version) 0;
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
