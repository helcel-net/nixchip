{
  lib,
  fetchFromGitHub,
  cocotb,
  cmake,
  ninja,
  nix-update-script,
  version ? "unstable-2026-11-18",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "f20d0e4aefddbe28fde2ee901ff065601f5d1c42"
    else
      "refs/tags/v${version}",
  hash ? "sha256-W4RHna0X/wD3+qbpvcNtkcQGczXQx4thhf8kUuRy2gQ=",
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
  # Build requirement of newer cocotb that nixpkgs does not package yet.
  dynamic-metadata =
    pythonPkgs.dynamic-metadata or (pythonPkgs.buildPythonPackage rec {
      pname = "dynamic-metadata";
      version = "0.6.0";
      format = "wheel";
      src = pythonPkgs.fetchPypi {
        pname = "dynamic_metadata";
        inherit version format;
        dist = "py3";
        python = "py3";
        hash = "sha256-JP6wDXlNQJmHqQD3AnKw5H/KRIZ/ZkNt4cbJ5fgI5ig=";
      };
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
      dynamic-metadata
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
      # Shell out to git, which the sandboxed source tree is not.
      "--ignore=tests/pytest/test_version.py"
      # Needs a GHDL build with a GPI interface.
      "--deselect=tests/pytest/test_vhdl_libraries_multiple.py::test_toplevel_library"
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
