{
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-10-13",
  rev ?
    if lib.hasPrefix "unstable-" version then "bed8d4ff84333767aa923d469d339cd05c56a00a" else version,
  hash ? "sha256-+7eCjVQmb7TEKNfABbYIs+MRPbzuKwl7hMEtauVMO/M=",
  ...
}:

magic-vlsi.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "RTimothyEdwards";
    repo = "magic";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script { };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
