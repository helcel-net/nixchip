{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "chipyard";
  version = "1.13.0";

  src = fetchFromGitHub {
    owner = "ucb-bar";
    repo = "chipyard";
    tag = finalAttrs.version;
    hash = "sha256-9bDE32C31/3J/ij/FWaDqEEmGW9gXtR33mvCgYWroQo=";
  };

  dontConfigure = true;
  dontBuild = true;
  dontPatchShebangs = true;
  dontCheckForBrokenSymlinks = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/chipyard" "$out/bin"
    cp -R . "$out/share/chipyard"

    cat > "$out/bin/chipyard-path" <<EOF
    #!${stdenvNoCC.shell}
    echo "$out/share/chipyard"
    EOF

    cat > "$out/bin/chipyard-init" <<EOF
    #!${stdenvNoCC.shell}
    set -eu
    target="\''${1:-chipyard-${finalAttrs.version}}"
    mkdir -p "\$target"
    cp -R "$out/share/chipyard/." "\$target/"
    chmod -R u+w "\$target"
    echo "\$target"
    EOF

    chmod +x "$out/bin/chipyard-path" "$out/bin/chipyard-init"

    runHook postInstall
  '';

  meta = {
    description = "Agile RISC-V SoC design framework";
    homepage = "https://github.com/ucb-bar/chipyard";
    license = lib.licenses.bsd3;
    mainProgram = "chipyard-init";
    platforms = lib.platforms.unix;
  };
})
