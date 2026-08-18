{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-08-18",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "e3e86b57585bd614247eef10a9d3aa6b549ad503"
    else
      "v${version}",
  hash ? "sha256-XiiMN1Z7XQ6TYhdXK9kc//J7bqdt8EKzUx4s/19qxU8=",
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
