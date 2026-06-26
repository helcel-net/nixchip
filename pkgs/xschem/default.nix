{
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-06-25",
  rev ? "c8b26a17d8d53ce7fbd9e7d45ab6bb03e75996e0",
  hash ? "sha256-OpFMBiR7UZ4nLxcrD1hgrEvnuccwYgTy2mTHjA3/E0w=",
  ...
}:

xschem.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "StefanSchippers";
    repo = "xschem";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "xschem";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
