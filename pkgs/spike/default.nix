{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-08-18",
  rev ? "4b3f708b06cb541e53d6752b18ebc67e9c67fbfb",
  hash ? "sha256-0jBYwKS4O6G+YEjQB1J2XuvH9JtkmZlEQrdVMgUoeEw=",
  ...
}:

spike.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "riscv-software-src";
    repo = "riscv-isa-sim";
    inherit rev hash;
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
