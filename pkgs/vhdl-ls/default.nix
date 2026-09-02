{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-09-02",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "a0fc2019d95e371d4ff3199a36aaaf0ba32c7145"
    else
      "v${version}",
  hash ? "sha256-rsbESQ9GYq3W1V26nfrydW/J+TJKoXxRFwsz0NRf+fo=",
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
