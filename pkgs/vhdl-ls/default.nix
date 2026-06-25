{
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version,
  rev,
  hash,
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
