{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "unstable-2026-11-17",
  rev ?
    if builtins.match ".*unstable.*" version != null then
      "53911acd6dfaa113c188d11d20b2ae290aa60a6b"
    else
      "v${version}",
  hash ? "sha256-NZ/0XJFBkxqEORKb+K7IlCCb+5VaMwourZ88Njzjlmw=",
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
