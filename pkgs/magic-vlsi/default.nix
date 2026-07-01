{ 
  lib,
  fetchFromGitHub,
  magic-vlsi,
  nix-update-script,
  version ? "unstable-2026-06-25",
  rev ? if lib.hasPrefix "unstable-" version then "60061ea33fac62be6277f2ee2f54711849d586dc" else version,
  hash  ? "sha256-uqClBVSfSLIgkNRzttNpSdgo/9ia6zMLbRosRWI0c5c=",
  ...
}:

magic-vlsi.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "RTimothyEdwards";
    repo = "magic";
    inherit rev hash;
  };
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script { };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
