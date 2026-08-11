{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "unstable-2026-08-11",
  rev ?
    if builtins.match ".*unstable.*" version != null then
      "31f5ebf340fea0425554fbe618dc750444593854"
    else
      "v${version}",
  hash ? "sha256-to6oAxCvFg2qKSUJORCaTgwu/knqleDvvMzWAzNB9co=",
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
