{
  lib,
  stdenv,
  makeWrapper,
  python3,
  openram,
  cacti,
}:

let
  pythonEnv = python3.withPackages (ps: [
    openram
  ]);
in
stdenv.mkDerivation {
  pname = "openram-wrapper";
  version = openram.version;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    makeWrapper ${pythonEnv}/bin/python3 $out/bin/openram-ram \
      --add-flag "${openram}/share/openram/sram_compiler.py" \
      --set CACTI_EXECUTABLE "${cacti}/bin/cacti" \
      --set OPENRAM_HOME "${openram}/share/openram/compiler" \
      --set OPENRAM_TECH "${openram}/share/openram/technology"

    makeWrapper ${pythonEnv}/bin/python3 $out/bin/openram-rom \
      --add-flag "${openram}/share/openram/rom_compiler.py" \
      --set CACTI_EXECUTABLE "${cacti}/bin/cacti" \
      --set OPENRAM_HOME "${openram}/share/openram/compiler" \
      --set OPENRAM_TECH "${openram}/share/openram/technology"

    runHook postInstall
  '';

  meta = {
    description = "Wrapper scripts for OpenRAM SRAM/ROM compilers";
    homepage = "https://github.com/VLSIDA/openram";
    license = lib.licenses.bsd3;
    mainProgram = "openram-ram";
    platforms = lib.platforms.unix;
  };
}
