{
  fetchFromGitHub,
  openroad,
  nix-update-script,
  version ? "unstable-2026-10-06",
  rev ? "90e09c40127d4d788f022a334bf59709594be637",
  hash ? "sha256-xL7KWQGFuoaQgRBnvsxC1/LyPBu7knXDID/6xnisCUQ=",
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
