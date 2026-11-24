{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-11-24",
  rev ? "982f078e65ab52d5d9a91248c2178f5399df7783",
  hash ? "sha256-pKTfuQpY/Lg6VbWMrFXwUaYmNjkLqDH400k2k5q7lT0=",
  ...
}:

spike.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "riscv-software-src";
    repo = "riscv-isa-sim";
    inherit rev hash;
    # berkeley-softfloat-3 became a submodule upstream.
    fetchSubmodules = true;
  };
  # installCheckPhase runs a RISC-V hello-world via spike+pk; the CLI flags
  # change across releases and the test breaks against HEAD.
  doInstallCheck = false;
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "spike";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
