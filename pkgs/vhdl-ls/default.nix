{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "25516d515610607f37cfe470b3ad72e74d169b9e"
    else
      "v${version}",
  hash ? "sha256-FTM2rCt9xCshOwi5xTiVjzc33SX+tgu5iE++2Q8PPm0=",
  ...
}:

vhdl_ls.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "VHDL-LS";
    repo = "rust_hdl";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "vhdl-ls";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
