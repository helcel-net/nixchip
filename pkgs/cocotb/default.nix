{
  lib,
  fetchFromGitHub,
  cocotb,
  cmake,
  ninja,
  nix-update-script,
  version ? "unstable-2026-09-15",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "079a2d4609fc3486422e3efa4ae5b2c4ae19449d"
    else
      "refs/tags/v${version}",
  hash ? "sha256-b00xh8GrVP9uhJQm7F871uo3WgpdbYC12+oBzjhqRcU=",
  ...
}:

let
  pythonPkgs = cocotb.pythonModule.pkgs;
  # cocotb master's version provider (setuptools_git_versioning.scikit_metadata)
  # only exists from setuptools-git-versioning 3.1.0. Bump while nixpkgs is
  # older; this becomes a no-op once the pin catches up.
  setuptools-git-versioning =
    if lib.versionAtLeast pythonPkgs.setuptools-git-versioning.version "3.1.0" then
      pythonPkgs.setuptools-git-versioning
    else
      pythonPkgs.setuptools-git-versioning.overridePythonAttrs (old: rec {
        version = "3.1.0";
        src = fetchFromGitHub {
          owner = "dolfinus";
          repo = "setuptools-git-versioning";
          tag = "v${version}";
          hash = "sha256-d6d8taSSAjvirivf1WaEICq0XbrYQzC2LB//LpGpHhI=";
        };
        postPatch = ''
          substituteInPlace pyproject.toml \
            --replace-fail 'dynamic = ["version"]' 'version = "${version}"'
        '';
        # 3.1.0's suite needs scikit-build-core/pytest-xdist in the check
        # env; this is a build-time-only shim, so skip it.
        doCheck = false;
      });
in
(cocotb.overridePythonAttrs (
  old:
  lib.optionalAttrs (lib.hasPrefix "unstable-" version) {
    # nixpkgs disables cocotb on python >= 3.14, which matches the 2.0.x
    # releases but is stale for the branch build: master raises only on
    # >= 3.15 (setup.py max_python3_minor_version = 14).
    disabled = false;
    # master builds the GPI/simulator libraries with CMake via scikit-build-core
    # (cocotb/cocotb ae0f3e3f5) instead of setuptools extensions. nixpkgs still
    # drives setup.py directly, which now ships no cocotb.simulator at all.
    format = "pyproject";
    build-system = [
      pythonPkgs.scikit-build-core
      pythonPkgs.setuptools
      setuptools-git-versioning
      pythonPkgs.find-libpython
    ];
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
      cmake
      ninja
    ];
    dontUseCmakeConfigure = true;
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
