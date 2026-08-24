{
  lib,
  fetchFromGitHub,
  cocotb,
  nix-update-script,
  version ? "unstable-2026-07-03",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "0ed808ff78b1117277b0f769f56504f233c55614"
    else
      "refs/tags/v${version}",
  hash ? "sha256-wk1WqIrNDTH39Wrgc5OjrZp/8bbTZkNWGIbm4dZkPZc=",
  ...
}:

(cocotb.overridePythonAttrs (
  old:
  lib.optionalAttrs (lib.hasPrefix "unstable-" version) {
    # nixpkgs disables cocotb on python >= 3.14, which matches the 2.0.x
    # releases but is stale for the branch build: master raises only on
    # >= 3.15 (setup.py max_python3_minor_version = 14).
    disabled = false;
  }
)).overrideAttrs
  (old: {
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
