{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "unstable-2026-11-03",
  rev ?
    if builtins.match ".*unstable.*" version != null then
      "2d74073d3f20ddfe6d96f57d61cb1e20fe6a1fec"
    else
      "v${version}",
  hash ? "sha256-ZsaKQFK8KQwW9P4xmr8Jl628SHkmpNcHAkiRVNpTFzA=",
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
