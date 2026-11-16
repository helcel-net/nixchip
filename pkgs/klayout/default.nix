{
  fetchFromGitHub,
  klayout,
  nix-update-script,
  version ? "unstable-2026-11-10",
  rev ?
    if builtins.match ".*unstable.*" version != null then
      "06b8ff4909ad1696c06c634183d8fd0eaa8a1b83"
    else
      "v${version}",
  hash ? "sha256-XPHV0pfHnRuwnMU5FLwPFyJramP23dLxPbCRc7NcGMs=",
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
