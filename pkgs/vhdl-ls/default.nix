{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-11-03",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "9ef80a7241ad6024be629b60f4681c145b6db3c7"
    else
      "v${version}",
  hash ? "sha256-F00aV9ui1ctk4IbkiOCnV3PkX88K4OIUP4x5bNZ3jbc=",
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
