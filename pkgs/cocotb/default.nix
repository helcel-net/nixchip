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
  hash ? "sha256-H2HZDmEVLgFewQBlIwy58ZsGFegBTTKeRnFSi94YWBs=",
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
