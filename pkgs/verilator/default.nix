{
  lib,
  stdenv,
  fetchFromGitHub,
  perl,
  flex,
  bison,
  python3,
  autoconf,
  which,
  help2man,
  makeWrapper,
  systemc,
  git,
  numactl,
  coreutils,
  gdb,
  version,
  hash,
  doCheck ? true,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "verilator";
  inherit version;

  src = fetchFromGitHub {
    owner = "verilator";
    repo = "verilator";
    tag = "v${finalAttrs.version}";
    inherit hash;
  };

  enableParallelBuilding = true;

  buildInputs = [
    perl
    systemc
    (python3.withPackages (
      pp: with pp; [
        distro
      ]
    ))
  ];

  nativeBuildInputs = [
    makeWrapper
    flex
    bison
    autoconf
    help2man
    git
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    gdb
  ];

  nativeCheckInputs = [
    which
    coreutils
    python3
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    numactl
  ];

  inherit doCheck;
  checkTarget = "test";

  preConfigure = "autoconf";

  postPatch = ''
    for path in bin src nodist docs/bin examples/xml_py test_regress ci; do
      if [ -e "$path" ]; then
        patchShebangs "$path"
      fi
    done

    if [ -f bin/verilator ]; then
      substituteInPlace bin/verilator --replace-fail "/bin/echo" "${coreutils}/bin/echo" || true
    fi
  '';

  preCheck = ''
    export PATH=$PWD/bin:$PATH
  '';

  env = {
    VERILATOR_SRC_VERSION = "v${finalAttrs.version}";
    SYSTEMC_INCLUDE = "${lib.getDev systemc}/include";
    SYSTEMC_LIBDIR = "${lib.getLib systemc}/lib";
  };

  meta = {
    changelog = "https://github.com/verilator/verilator/blob/v${finalAttrs.version}/Changes";
    description = "Fast and robust (System)Verilog simulator/compiler and linter";
    homepage = "https://www.veripool.org/verilator";
    license = with lib.licenses; [
      lgpl3Only
      artistic2
    ];
    mainProgram = "verilator";
    platforms = lib.platforms.unix;
  };
})
