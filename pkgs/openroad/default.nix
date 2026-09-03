{
  fetchFromGitHub,
  openroad,
  nix-update-script,
  version ? "unstable-2026-09-02",
  rev ? "2ac546acaf350111732655ae402ea952d06d362c",
  hash ? "sha256-Vr1lfUhcqOJGodUtm0va9iROmKdoHkb+lfXRJtvx1Fk=",
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
