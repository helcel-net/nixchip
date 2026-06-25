{
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "8.3.629",
  hash ? "sha256-K/w2El2jkXN8qIa0kWvN8rCKWzjd8DcM3O6hb5UVQnw=",
  ...
}:

magic-vlsi.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "RTimothyEdwards";
    repo = "magic";
    tag = version;
    inherit hash;
  };
  passthru = (old.passthru or { }) // { updateScript = nix-update-script { }; nixchipUpdate = true; nixchipCI = true; };
})
