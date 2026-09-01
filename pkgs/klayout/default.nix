{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "unstable-2026-09-01",
  rev ?
    if builtins.match ".*unstable.*" version != null then
      "e71272c3b178105bd2a2f25af54673a7af7ed60d"
    else
      "v${version}",
  hash ? "sha256-ZNljSRX7zAS8owzc6qxwsU2CBjS7j1IFzKeNh1DOlBU=",
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
