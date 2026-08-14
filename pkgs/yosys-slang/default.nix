{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  python3,
  tomlplusplus,
  nix-update-script,
  yosys,
  version ? "unstable-2026-08-13",
  rev ? "ce38835520fbdf422304a6f6a2f1c437c3ba98c2",
  hash ? "sha256-SyIklQs2IfXhAIvUZN//B7vSmffS5HxVQAQlEVyfcxY=",
}:

let
  # The bundled slang fetches boost::regex over the network via FetchContent,
  # which the Nix sandbox blocks. Vendor the exact tag it asks for and point
  # FetchContent at it instead.
  boostRegex = fetchFromGitHub {
    owner = "MikePopoloski";
    repo = "regex";
    tag = "boost-1.91.0";
    hash = "sha256-/a3wW6hMQwxrxs7pX3KKZGKFTm78HALaquBAwDMJfq4=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "yosys-slang";
  inherit version;

  src = fetchFromGitHub {
    owner = "povik";
    repo = "yosys-slang";
    inherit rev hash;
    fetchSubmodules = true;
  };

  postPatch = ''
    substituteInPlace third_party/slang/external/CMakeLists.txt \
      --replace-fail 'GIT_REPOSITORY ''${GITHUB_PREFIX}MikePopoloski/regex.git' "SOURCE_DIR ${boostRegex}" \
      --replace-fail "GIT_TAG boost-1.91.0" ""
  '';

  nativeBuildInputs = [
    cmake
    python3
  ];

  # slang's bundled CMake fetches tomlplusplus unless find_package satisfies
  # its FIND_PACKAGE_ARGS 3.4, which the sandbox cannot do over the network.
  buildInputs = [ tomlplusplus ];

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
