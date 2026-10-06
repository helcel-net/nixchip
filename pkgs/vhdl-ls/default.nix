{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-10-06",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "dc8c090f7aeb9a95149eadc5e8b48f170382a8d4"
    else
      "v${version}",
  hash ? "sha256-y9x4DiSx/cUMRERLjRZtsyQg1xuy6bq5dWfgTa419mM=",
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
