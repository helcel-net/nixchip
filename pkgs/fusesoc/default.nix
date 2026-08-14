{
  fetchFromGitHub,
  fusesoc,
  lib,
  pydantic,
  # Optional newer edalize, supplied only by the branch-tracking attr; the
  # pinned fusesoc2 slot keeps nixpkgs' edalize untouched.
  edalize ? null,
  nix-update-script,
  version ? "unstable-2026-08-13",
  rev ?
    if lib.hasPrefix "unstable-" version then "c3060a9a93e1970fae6cbba037207cece1e53221" else version,
  hash ? "sha256-aP+RrQt+TIDt10fxxwSWxjSdzr1IrE6L9GuKWnCAprc=",
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
  # Newer fusesoc imports ToolResolutionError/get_edatool, which nixpkgs'
  # edalize 0.6.1 does not expose. Swap in the supplied edalize rather than
  # carrying two versions on PYTHONPATH.
  propagatedBuildInputs =
    (
      if edalize == null then
        (old.propagatedBuildInputs or [ ])
      else
        lib.filter (p: (p.pname or "") != "edalize") (old.propagatedBuildInputs or [ ])
    )
    ++ [ pydantic ]
    ++ lib.optional (edalize != null) edalize;
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
