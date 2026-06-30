{
  fetchFromGitHub,
  fusesoc,
  lib,
  pydantic,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ? if lib.hasPrefix "unstable-" version then "f15e1c8a76815c4f391231dd0e743e2b683c6b45" else version,
  hash ? "sha256-f5ao99G/m//sdrIM1j6AT+kAt7/Zl8xvV8zM2XvCWAU=",
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
