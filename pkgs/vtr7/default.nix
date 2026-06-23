{
  lib,
  stdenv,
  fetchFromGitHub,
  bison,
  flex,
  python3,
  pkg-config,
  zlib,
  readline,
  version ? "7",
  hash ? "sha256-/tb/ZA3k30oijfLHOLuE9OAEVRqj3bkb2Yx6aXnZ3uA=",
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "vtr";
  inherit version;

  src = fetchFromGitHub {
    owner = "verilog-to-routing";
    repo = "vtr-verilog-to-routing";
    tag = "vtr_v${finalAttrs.version}";
    fetchSubmodules = false;
    inherit hash;
  };

  nativeBuildInputs = [
    bison
    flex
    python3
    pkg-config
  ];

  buildInputs = [
    zlib
    readline
  ];

  enableParallelBuilding = true;

  buildFlags = [ "vpr" ];

  installPhase = ''
    runHook preInstall

    install -Dm755 vpr/vpr "$out/bin/vpr"

    install -Dm755 vtr_flow/scripts/run_vtr_flow.pl "$out/bin/run_vtr_flow.pl" || true
    install -Dm755 vtr_flow/scripts/run_vtr_task.pl "$out/bin/run_vtr_task.pl" || true

    mkdir -p "$out/share/vtr"
    cp -r vtr_flow "$out/share/vtr/"

    runHook postInstall
  '';

  meta = {
    description = "Verilog-to-Routing: open-source FPGA CAD flow for architecture research (legacy v7)";
    homepage = "https://verilogtorouting.org";
    license = lib.licenses.mit;
    mainProgram = "vpr";
    platforms = lib.platforms.linux;
  };
})
