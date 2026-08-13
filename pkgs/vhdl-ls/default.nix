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
  cargoHash ? "sha256-smBLfa/u6HYdJoMfNaycL6rAVppjVrugA4RlS7EtCdM=",
  ...
}:

vhdl_ls.overrideAttrs (old: {
  inherit version;
  # buildRustPackage reads cargoHash from its original args, so overrideAttrs
  # cannot reach it, while src comes from finalAttrs and does follow the
  # override. Re-point the vendor FOD's hash so it matches the bumped rev.
  cargoDeps = old.cargoDeps.overrideAttrs (o: {
    vendorStaging = o.vendorStaging.overrideAttrs { outputHash = cargoHash; };
  });
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
