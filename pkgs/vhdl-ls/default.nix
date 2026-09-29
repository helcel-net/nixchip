{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-09-29",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "cd7cfd7bf7aa873e76a3101663d10580ddb66c49"
    else
      "v${version}",
  hash ? "sha256-ej09aKHAg1gYgVU9Flx7DfDn1zFhpom0SoUDDaacefQ=",
  cargoHash ? "sha256-PQ8XKSH/Rh4LIOaZitHUYQW0NiDNH6qNu0kznYTxnDE=",
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
