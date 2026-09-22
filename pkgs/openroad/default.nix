{
  fetchFromGitHub,
  openroad,
  nix-update-script,
  version ? "unstable-2026-09-22",
  rev ? "50432012f4ea2372f4abbbb08e305e5c266b9c81",
  hash ? "sha256-F4AKxV+gGZ9sRnMdBo/Fc3gmSN/FwIJPXw1teo7tZ8w=",
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
