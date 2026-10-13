{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "unstable-2026-10-13",
  rev ?
    if builtins.match ".*unstable.*" version != null then
      "4d927b797d7e2fc9ab2d8ec29781fa6559851663"
    else
      "v${version}",
  hash ? "sha256-HqMrE7y9IziLD3QNcsgaLHJrUnUOvH2DLuJmDgCbA+M=",
  ...
}:

klayout.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "KLayout";
    repo = "klayout";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script { };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
