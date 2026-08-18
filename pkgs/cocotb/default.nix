{
  lib,
  fetchFromGitHub,
  cocotb,
  nix-update-script,
  version ? "unstable-2026-08-18",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "f51dcc21fe4a85f734503e688f65093f6d307476"
    else
      "refs/tags/v${version}",
  hash ? "sha256-RFwQrOY77sj16K2FLpBEI4lXOmRWQWGfd/07uMBofgQ=",
  ...
}:

cocotb.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "cocotb";
    repo = "cocotb";
    inherit rev hash;
    # .git_archival.txt is export-subst, so GitHub rewrites it when generating
    # the tarball and its hash drifts as refs change -- even for a pinned rev.
    # Fetch over git instead so the tree is stable.
    forceFetchGit = true;
  };
  pytestFlagsArray = (old.pytestFlagsArray or [ ]) ++ [
    "--ignore=tests/pytest/test_ipython_support.py"
  ];
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "cocotb";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
