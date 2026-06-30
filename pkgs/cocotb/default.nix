{
  lib,
  fetchFromGitHub,
  cocotb,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "869c45921d7595668acafe44922e3bb5257d649d"
    else
      "refs/tags/v${version}",
  hash ? "sha256-G0rsGw//7SUh6ahFMZds8ymKf7fMDt1bIbJrjFW5rjU=",
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
