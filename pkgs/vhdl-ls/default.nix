{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-09-15",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "7b710854606a8e229698c50484f41f31e7424b19"
    else
      "v${version}",
  hash ? "sha256-J2ILw+eUwf1SwTHcnqkYitS1DPElnmFYOewIAEP5FuM=",
  cargoHash ? "sha256-bJ80KyxWpVI04QMSZIS331jPbWHoLVe1P3pMEWGlKUY=",
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
