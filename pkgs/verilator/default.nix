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
  nix-update-script,
  version,
  rev,
  hash,
  doCheck ? true,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "verilator";
  inherit version;

  src = fetchFromGitHub {
    owner = "verilator";
    repo = "verilator";
    inherit rev hash;
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

  passthru.updateScript = nix-update-script {
    attrPath = "verilator";
    extraArgs = [ "--version=branch" ];
  };
  passthru.nixchipUpdate = true;
  passthru.nixchipCI = true;

  inherit doCheck;
  checkTarget = "test";

  preConfigure = "autoconf";

  postPatch = ''
        # bisonpre rewrites the include inside V3ParseBison.c to "verilog.h"
        # (via filename substitution) but saves the header as V3ParseBison.h;
        # add a make rule to copy V3ParseBison.h → verilog.h after the bison step.
        python3 - <<'PYEOF'
    with open('src/Makefile_obj.in', 'r') as f:
        c = f.read()
    # bisonpre rewrites the #include inside V3ParseBison.c to "verilog.h" (via
    # filename substitution) but saves the header as V3ParseBison.h.  Copy it so
    # the compiler finds it.  V3ParseGrammar.o already depends on V3ParseBison.c,
    # so the copy runs before that compilation step — no extra make rule needed.
    old = '$(PERL) $(BISONPRE) --yacc ''${YACC} -d -v -o V3ParseBison.c $<'
    new = old + '\n\tcp V3ParseBison.h verilog.h'
    c = c.replace(old, new)
    with open('src/Makefile_obj.in', 'w') as f:
        f.write(c)
    PYEOF

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
