{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-11-10",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "6435e740e0118a7b41486dd77f6a15f8f75941bb"
    else
      "v${version}",
  hash ? "sha256-6ER7R9jpABQNSXiff97lMdzA+Y9lJcQs/WF2i25/J9M=",
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
