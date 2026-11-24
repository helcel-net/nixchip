{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-11-24",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "60c4c18abda3dee05ca4760cdc33dfc325d1e4a7"
    else
      "v${version}",
  hash ? "sha256-Uq62KpoGn5wGCYgg8cw/SAy3s2V5chxwzrPLY6xzGuw=",
  cargoHash ? "sha256-hz7zR+mvAt3ojZriEs6nWrkK3u7vB3gTYXPhKXsNV1E=",
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
