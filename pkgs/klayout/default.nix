{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "0-unstable-2026-06-19",
  rev ? if builtins.match ".*unstable.*" version != null then "d352db146fb62f0bf73f5a6175a99f53fee6c933" else "v${version}",
  hash ? "sha256-fkvulQDHkqwhjsYAUhdkiU9EyH8PwEZQYCIyklu+XBQ=",
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
