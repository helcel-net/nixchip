{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "unstable-2026-10-23",
  rev ?
    if builtins.match ".*unstable.*" version != null then
      "7eb9a25b42242a97e61300ad3a1486e10937abf5"
    else
      "v${version}",
  hash ? "sha256-pIM26emo5UdwNdTyxL6kh1lyE0a0s5eBzPGeYnTrrWY=",
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
