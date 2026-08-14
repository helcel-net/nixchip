{
  fetchFromGitHub,
  fusesoc,
  lib,
  pydantic,
  nix-update-script,
  version ? "unstable-2026-08-11",
  rev ?
    if lib.hasPrefix "unstable-" version then "318ab3acf0b16fbc5d70de5d8750af312ffb2acd" else version,
  hash ? "sha256-1R02UVhgkp01mCO2lrGzhJS9m113kVHkx6+xPQ2L33Q=",
  ...
}:

let
  pep440Version =
    let
      rawTag = builtins.elemAt (lib.splitString "-" version) 0;
      tag = if builtins.match "[0-9].*" rawTag != null then rawTag else "0";
      shortRev = lib.substring 0 7 rev;
    in
    "${tag}1.dev1+g${shortRev}";
in
fusesoc.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "olofk";
    repo = "fusesoc";
    inherit rev hash;
  };
  propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ pydantic ];
  postPatch = (old.postPatch or "") + ''
    substituteInPlace pyproject.toml \
      --replace-quiet 'pydantic>=2.13.3' 'pydantic>=2.0'
  '';
  preBuild = (old.preBuild or "") + ''
    export SETUPTOOLS_SCM_PRETEND_VERSION="${pep440Version}"
  '';
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "fusesoc";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
