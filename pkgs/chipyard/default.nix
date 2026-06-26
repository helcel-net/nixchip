{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ? "0acc1e1de2d3284bcd4d876956932a013ffe1949",
  hash ? "sha256-vi0KRoioTPDdgZFITIOkAtMyWxuyAyMzwyqShGtVGZA=",
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "chipyard";
  inherit version;

  src = fetchFromGitHub {
    owner = "ucb-bar";
    repo = "chipyard";
    inherit rev hash;
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

  passthru.updateScript = nix-update-script { };
  passthru.nixchipUpdate = true;
  passthru.nixchipCI = true;

  meta = {
    description = "Agile RISC-V SoC design framework";
    homepage = "https://github.com/ucb-bar/chipyard";
    license = lib.licenses.bsd3;
    mainProgram = "chipyard-init";
    platforms = lib.platforms.unix;
  };
})
