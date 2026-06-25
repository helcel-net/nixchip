{
  fetchFromGitHub,
  amaranth,
  nix-update-script,
  version ? "0-unstable-2026-06-25",
  rev ? "c9be3e4a9e932c25e361d0085af31c5b420efc41",
  hash ? "sha256-0UfGuvfJTbF9enn6bb+75nKjLxsagQjnTL3UVKjqY+o=",
  ...
}:

amaranth.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "amaranth-lang";
    repo = "amaranth";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "amaranth";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
