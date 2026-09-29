{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "unstable-2026-09-29",
  rev ?
    if builtins.match ".*unstable.*" version != null then
      "5fa733e1680212e4ceda532ca5fa6ea707c654de"
    else
      "v${version}",
  hash ? "sha256-jHPgFBQJFmue9hUZ1knwAWhAwmff2dwRUbB9kIaaL9c=",
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
