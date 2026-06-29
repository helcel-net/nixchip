{
  lib,
  stdenvNoCC,
  makeWrapper,
  gnumake,
  klayout,
  openroad,
  openroad-flow-scripts,
  tcl,
  yosys-full,
  yosys-slang,
}:

stdenvNoCC.mkDerivation {
  pname = "openroad-flow-scripts-wrapper";
  version = openroad-flow-scripts.version;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    makeWrapper ${gnumake}/bin/make $out/bin/orfs \
      --add-flag "-f" \
      --add-flag "${openroad-flow-scripts}/share/openroad-flow-scripts/flow/Makefile" \
      --set FLOW_HOME "${openroad-flow-scripts}/share/openroad-flow-scripts/flow" \
      --prefix PATH : ${lib.makeBinPath [
        yosys-full
        yosys-slang
        openroad
        klayout
        tcl
      ]}

    runHook postInstall
  '';

  meta = {
    description = "Wrapper script for OpenROAD Flow Scripts";
    homepage = "https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts";
    license = lib.licenses.bsd3;
    mainProgram = "orfs";
    platforms = lib.platforms.unix;
  };
}
