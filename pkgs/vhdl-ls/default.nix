{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-11-17",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "0c8a2e1c27795b283cf6cd7c18c73c1b0d6c6820"
    else
      "v${version}",
  hash ? "sha256-Dfom+ixxGQTYoBDd8FE3z/F/w6uLrODyYldlKOpVUEM=",
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
