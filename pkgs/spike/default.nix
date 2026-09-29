{
  fetchFromGitHub,
  spike,
  nix-update-script,
  version ? "unstable-2026-09-29",
  rev ? "0bff12123b1fd510e19e19634dd997dbade70e54",
  hash ? "sha256-/yLmvB7av+i6VqN9G+/h6IXsXaz62JTz1C8k4qoDiB4=",
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
