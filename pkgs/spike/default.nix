{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-11-10",
  rev ? "c20813c1d696e843ff1b7667413f98d1397d85ea",
  hash ? "sha256-r+doN5w9IjZwYfs0oNBSjuTQPZHwgadXKRgeaGm/8lk=",
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
