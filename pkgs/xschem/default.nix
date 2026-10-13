{
  lib,
  fetchFromGitHub,
  xschem,
  nix-update-script,
  version ? "unstable-2026-10-13",
  rev ?
    if lib.hasPrefix "unstable-" version then "0fa7b0ed71548c1263b671af94ec5864ea89a409" else version,
  hash ? "sha256-gZu5nMungPZWx7e3E79pJUeTVZ+/hqLpdIE5IrdQN70=",
  ...
}:

xschem.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "StefanSchippers";
    repo = "xschem";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "xschem";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
