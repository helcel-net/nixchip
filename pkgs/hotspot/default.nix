{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ? if lib.hasPrefix "unstable-" version then "f18831e48cef5d62580585cca0d7fab6c71bc3cc" else "v${version}",
  hash ? "sha256-JlSEbvuT+szQ6cGab/n/WdEhh3XZSR82gVUWFfueqFw=",
}:

stdenv.mkDerivation {
  pname = "hotspot";
  inherit version;

  src = fetchFromGitHub {
    owner = "uvahotspot";
    repo = "HotSpot";
    inherit rev hash;
  };

  enableParallelBuilding = true;

  makeFlags = [
    "CC=${stdenv.cc.targetPrefix}cc"
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 hotspot "$out/bin/hotspot"
    install -Dm755 hotfloorplan "$out/bin/hotfloorplan"
    install -Dm644 libhotspot.a "$out/lib/libhotspot.a"
    install -Dm644 hotspot.h "$out/include/hotspot.h"
    install -Dm644 hotspot-iface.h "$out/include/hotspot-iface.h"

    mkdir -p "$out/share/hotspot"
    cp -R examples scripts README.md README_archive LICENSE *.config "$out/share/hotspot/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };
  passthru.nixchipUpdate = true;
  passthru.nixchipCI = true;

  meta = {
    description = "Pre-RTL thermal simulator for 2D/3D integrated circuits";
    homepage = "https://github.com/uvahotspot/HotSpot";
    license = lib.licenses.bsd3;
    mainProgram = "hotspot";
    platforms = lib.platforms.unix;
  };
}
