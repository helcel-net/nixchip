{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  version ? "7.0",
  hash ? "sha256-AM8kTu0Rxpee3easDBKtu6+ld6lmpNVNO1z2jOQmhls=",
}:

stdenv.mkDerivation {
  pname = "hotspot";
  inherit version;

  src = fetchFromGitHub {
    owner = "uvahotspot";
    repo = "HotSpot";
    rev = "v${version}";
    inherit hash;
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
