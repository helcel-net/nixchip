{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-09-15",
  rev ? "1e05ddac3a6c351bfc0aeed0cf3a68940e7200ab",
  hash ? "sha256-50DQiSw1JN9MHTGf/KlpSnKrMlzAjhkOovRyyfgIOWE=",
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
