{
  fetchFromGitHub,
  openroad,
  nix-update-script,
  version ? "unstable-2026-07-02",
  rev ? "3a15695692bdb3cdc7fa47c5e6b60fbd312b6711",
  hash ? "sha256-ARWJIgT84mQb4VspScMmjIFg7O48yWXBoirt86Nxz1U=",
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
