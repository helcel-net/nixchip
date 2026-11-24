{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "unstable-2026-11-24",
  rev ?
    if builtins.match ".*unstable.*" version != null then
      "b98a9e65bca8d75e1d30dc71cb5b82d6b09f6823"
    else
      "v${version}",
  hash ? "sha256-PNRVLl93aClju06fROow5mVvQuRddoj4uqbY0fWKv7I=",
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
