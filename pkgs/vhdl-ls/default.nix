{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-08-11",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "638b5b72204451c9dd597558216c5c38be2c5cb6"
    else
      "v${version}",
  hash ? "sha256-ymlCm9Vj1vbqWdKkeEQPgvYR3m01lBa26M4896+bNIc=",
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
