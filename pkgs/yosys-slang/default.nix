{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  python3,
  nix-update-script,
  yosys,
  rev ? "3e0db86b102953ee2a56a64eddfe02a50273e565",
  hash ? "sha256-mhAYkI0aYrttem6DE08bQ/bsITEaCzBd1MQBl0jQmCA=",
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "yosys-slang";
  version = "0-unstable-2026-06-23";

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
    extraArgs = [ "--version=unstable" ];
  };

  meta = {
    description = "SystemVerilog frontend plugin for Yosys based on the slang library";
    homepage = "https://github.com/povik/yosys-slang";
    license = lib.licenses.isc;
    mainProgram = "yosys-slang";
    platforms = lib.platforms.unix;
  };
})
