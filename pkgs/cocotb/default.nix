{
  lib,
  fetchFromGitHub,
  cocotb,
  nix-update-script,
  version ? "unstable-2026-09-01",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "ca64add11543021f36578fbc4731c94c9483c93f"
    else
      "refs/tags/v${version}",
  hash ? "sha256-3pCwZbsNtCh1z3RzPvpuUFIDigCu2V+eWqURHBkGst8=",
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
