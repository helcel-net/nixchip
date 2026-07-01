{
  lib,
  fetchFromGitHub,
  cocotb,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "2a7575d591a3be474288f5236a06538a55b5f21f"
    else
      "refs/tags/v${version}",
  hash ? "sha256-zdGusYRXKX2m0BZjR6ePNiSwiAK9M4NnjraA3xRHjNQ=",
  ...
}:

cocotb.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "cocotb";
    repo = "cocotb";
    inherit rev hash;
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
