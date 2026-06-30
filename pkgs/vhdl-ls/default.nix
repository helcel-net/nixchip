{
  lib,
  fetchFromGitHub,
  vhdl_ls,
  nix-update-script,
  version ? "unstable-2026-06-25",
  rev ?
    if lib.hasPrefix "unstable-" version then
      "873b2647712e2f6b1b775c8d555372120f386373"
    else
      "v${version}",
  hash ? "sha256-wN1MpYIyuaQ23poyB/0TbFgeaTFvALczCAb/tykzq8k=",
  ...
}:

vhdl_ls.overrideAttrs (old: {
  inherit version;
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
