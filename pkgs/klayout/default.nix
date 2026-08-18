{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "unstable-2026-08-18",
  rev ?
    if builtins.match ".*unstable.*" version != null then
      "5ff3bb4c4b9cd20ba7ebc24b1ccb214fb52efecf"
    else
      "v${version}",
  hash ? "sha256-u96R4jKZl0zoGlAR9tkHCylrQi4xo+YfxGy0S1CBmHo=",
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
