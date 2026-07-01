{
  lib,
  fetchFromGitHub,
  cocotb,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "8866ab4184eb074757fa3f2d1c9a56023a392931"
    else
      "refs/tags/v${version}",
  hash ? "sha256-bpDLjuprdwAFy3mBCj3u3Y6KA1ljieu9nTQzRcG0g4s=",
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
