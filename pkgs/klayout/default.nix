{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "unstable-2026-10-06",
  rev ?
    if builtins.match ".*unstable.*" version != null then
      "0460c3e253393063c76c163b18d87f1ad7c47fb5"
    else
      "v${version}",
  hash ? "sha256-RL4Vnb/n01cohbpghdivTgCQkrG1MIC3Z5arcr2JzFw=",
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
