{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  python3,
  yosys,
  rev ? "009058e4c2615f282db27cb484c4296b28f4ac5b",
  hash ? "sha256-ODpiPcv6/Nbt+v6or9jc1GCiZYVMf4JRQSR32pf2I8M=",
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "yosys-slang";
  version = "0-unstable-2026-06-20";

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

  meta = {
    description = "SystemVerilog frontend plugin for Yosys based on the slang library";
    homepage = "https://github.com/povik/yosys-slang";
    license = lib.licenses.isc;
    mainProgram = "yosys-slang";
    platforms = lib.platforms.unix;
  };
})
