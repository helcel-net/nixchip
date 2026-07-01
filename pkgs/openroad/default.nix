{
  fetchFromGitHub,
  openroad,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ? "b65c274cadefe2151aa7eee32e1be9026e8ff14a",
  hash ? "sha256-vL1AH+eQislAs2yZkxGj8FoPZbt5+T/m3qt76ymlJQ8=",
  patches ? [ ],
  ...
}:

openroad.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "The-OpenROAD-Project";
    repo = "OpenROAD";
    fetchSubmodules = true;
    inherit rev hash;
  };
  inherit patches;
  doCheck = false;
  doInstallCheck = false;
  postPatch = (old.postPatch or "") + ''
    if [ -f src/web/src/embed_web_assets.py ]; then
      chmod +x src/web/src/embed_web_assets.py
      patchShebangs src/web/src/embed_web_assets.py
    fi
    if [ -f src/web/src/embed_report_assets.py ]; then
      chmod +x src/web/src/embed_report_assets.py
      patchShebangs src/web/src/embed_report_assets.py
    fi
  '';
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "openroad";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
