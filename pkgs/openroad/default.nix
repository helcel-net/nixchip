{
  fetchFromGitHub,
  openroad,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ? "42735125d521989ee7097c2cb6242ee98c50f8bb",
  hash ? "sha256-Vk2Jygke4+fYRoFABfJLP6ryT+zz2z03u0VjOvHwAbw=",
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
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "openroad";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
