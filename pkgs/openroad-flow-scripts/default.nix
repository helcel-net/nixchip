{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  gnumake,
  nix-update-script,
  version ? "unstable-2026-09-22",
  rev ? "3a964e13f11a4e435aac01ffa14db0a7d2853720",
  hash ? "sha256-T+6VgR54EXNLYrIvGqAOeuNUT/QRyTQcx7EBxspJkk0=",
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "openroad-flow-scripts";
  inherit version;

  src = fetchFromGitHub {
    owner = "The-OpenROAD-Project";
    repo = "OpenROAD-flow-scripts";
    inherit rev hash;
  };

  dontConfigure = true;
  dontBuild = true;
  dontPatchShebangs = true;
  dontCheckForBrokenSymlinks = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/openroad-flow-scripts" "$out/bin"
    cp -R . "$out/share/openroad-flow-scripts"

    cat > "$out/bin/openroad-flow-scripts-path" <<EOF
    #!${stdenvNoCC.shell}
    echo "$out/share/openroad-flow-scripts"
    EOF

    cat > "$out/bin/openroad-flow-scripts-init" <<EOF
    #!${stdenvNoCC.shell}
    set -eu
    target="\''${1:-openroad-flow-scripts-${finalAttrs.version}}"
    mkdir -p "\$target"
    cp -R "$out/share/openroad-flow-scripts/." "\$target/"
    chmod -R u+w "\$target"
    echo "\$target"
    EOF

    cat > "$out/bin/openroad-flow-scripts-make" <<EOF
    #!${stdenvNoCC.shell}
    set -eu
    root="\''${ORFS_ROOT:-\$PWD}"
    exec ${gnumake}/bin/make -C "\$root/flow" "\$@"
    EOF

    chmod +x \
      "$out/bin/openroad-flow-scripts-path" \
      "$out/bin/openroad-flow-scripts-init" \
      "$out/bin/openroad-flow-scripts-make"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    attrPath = "openroad-flow-scripts";
    extraArgs = [ "--version=branch" ];
  };
  passthru.nixchipUpdate = true;
  passthru.nixchipCI = true;

  meta = {
    description = "OpenROAD RTL-to-GDS flow scripts";
    homepage = "https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts";
    license = lib.licenses.bsd3;
    mainProgram = "openroad-flow-scripts-init";
    platforms = lib.platforms.unix;
  };
})
