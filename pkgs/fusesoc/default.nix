{
  fetchFromGitHub,
  fusesoc,
  nix-update-script,
  version ? "0-unstable-2026-06-25",
  rev ? "f15e1c8a76815c4f391231dd0e743e2b683c6b45",
  hash ? "sha256-f5ao99G/m//sdrIM1j6AT+kAt7/Zl8xvV8zM2XvCWAU=",
  ...
}:

fusesoc.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "olofk";
    repo = "fusesoc";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "fusesoc";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
