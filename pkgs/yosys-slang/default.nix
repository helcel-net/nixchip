{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  python3,
  nix-update-script,
  yosys,
  version ? "unstable-2026-06-26",
  rev ? "6760afa2c9b9ba231a9c6a9e94f0939dd39f0a20",
  hash ? "sha256-zDR0BBeTTjYZfUXgHZsMfcEtAadjU1MIwk/p4ruUcqA=",
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
