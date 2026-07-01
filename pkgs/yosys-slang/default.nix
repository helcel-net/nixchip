{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  python3,
  nix-update-script,
  yosys,
  version ? "unstable-2026-07-01",
  rev ? "b08e87ca0de19490f98f5c2937fd933c55cbfc30",
  hash ? "sha256-lQaMyl5wD1jg2WvJnwiMYhvLAK70M7UINcXtR2XnmLU=",
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "yosys-slang";
  inherit version;

  src = fetchFromGitHub {
    owner = "povik";
    repo = "yosys-slang";
    inherit rev hash;
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    python3
  ];

  cmakeFlags = [
    "-DYOSYS_CONFIG=${yosys}/bin/yosys-config"
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 slang.so "$out/share/yosys/plugins/slang.so"

    mkdir -p "$out/bin"
    cat > "$out/bin/yosys-slang" <<EOF
    #!${stdenv.shell}
    exec ${yosys}/bin/yosys -m "$out/share/yosys/plugins/slang.so" "\$@"
    EOF
    chmod +x "$out/bin/yosys-slang"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    attrPath = "yosys-slang0";
    extraArgs = [ "--version=branch" ];
  };
  passthru.nixchipUpdate = true;
  passthru.nixchipCI = true;

  meta = {
    description = "SystemVerilog frontend plugin for Yosys based on the slang library";
    homepage = "https://github.com/povik/yosys-slang";
    license = lib.licenses.isc;
    mainProgram = "yosys-slang";
    platforms = lib.platforms.unix;
  };
})
