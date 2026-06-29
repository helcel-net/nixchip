{
  pkgs,
  basePkgs ? pkgs,
}:

let
  inherit (pkgs) lib;

  callPackage = lib.callPackageWith (pkgs // nixchipPackages);

  optionalPackage =
    name:
    let
      package = builtins.tryEval (builtins.getAttr name basePkgs);
    in
    lib.optional package.success package.value;

  optionalUnfreePackage =
    name: lib.optionals (basePkgs.config.allowUnfree or false) [ (builtins.getAttr name basePkgs) ];

  yosysWithPlugins =
    let
      base =
        if basePkgs.yosys ? withPlugins then
          basePkgs.yosys.withPlugins (
            with basePkgs.yosys.allPlugins; lib.optionals (basePkgs.yosys.allPlugins ? ghdl) [ ghdl ]
          )
        else
          basePkgs.yosys;
    in
    base.overrideAttrs (old: {
      meta = (old.meta or { }) // {
        description = "Yosys Open SYnthesis Suite with GHDL plugin for VHDL support";
      };
    });

  # Naming convention:
  # - Unsuffixed custom package attrs track upstream branch HEAD and use
  #   unstable-YYYY-MM-DD versions.
  # - Numbered attrs are fixed release slots for side-by-side tool versions.
  nixchipPackages = rec {

    # ── Simulators ─────────────────────────────────────────────────────────────
    verilator3 = callPackage ./verilator {
      version = "3.926";
      rev = "v3.926";
      hash = "sha256-sbUmoeyUVyZniigixGKjLnHskiPvyMQFpeGo5PRMdRk=";
      doCheck = false;
    };
    verilator4 = callPackage ./verilator {
      version = "4.228";
      rev = "v4.228";
      hash = "sha256-ToYad8cvBF3Mio5fuT4Ce4zXbWxFxd6smqB1TxvlHao=";
      doCheck = false;
    };
    verilator5 = basePkgs.verilator;
    verilator = callPackage ./verilator {
      doCheck = false;
    };

    systemc2 = callPackage ./systemc {
      version = "2.3.4";
      rev = "2.3.4";
      hash = "sha256-CzjrkgvMRmL82omffz+bTI9JR900sdRmhZIhcyflSGo=";
    };
    systemc3 = callPackage ./systemc {
      version = "3.0.2";
      rev = "3.0.2";
      hash = "sha256-v/PcQu0m/7zyx2TtpZrLFbHtknahgVCkzcRi3lgrRGw=";
    };
    systemc = callPackage ./systemc {
      cxxStandard = "17";
    };

    ghdl6 = callPackage ./ghdl {
      ghdl = basePkgs.ghdl;
      version = "6.0.0";
      rev = "v6.0.0";
      hash = "sha256-Q5lAWMa1SFjoIJTdWlHSbS4Cg5RYWiej8F05Xrz9ArY=";
    };
    ghdl = callPackage ./ghdl {
      ghdl = basePkgs.ghdl;
    };
    nvc1 = basePkgs.nvc;
    nvc = nvc1;
    iverilog12 =  callPackage ./iverilog {
      iverilog = basePkgs.iverilog;
      version = "12.0";
      hash = "sha256-J9hedSmC6mFVcoDnXBtaTXigxrSCFa2AhhFd77ueo7I=";
    };
    iverilog13 = callPackage ./iverilog {
      iverilog = basePkgs.iverilog;
      version = "13.0";
      hash = "sha256-SfODx7K3UrDHMoKCbMFpxo4t9j9vG1oWF0RFS3dSUm4=";
    };
    iverilog = callPackage ./iverilog { iverilog = basePkgs.iverilog; };
    spike1 = basePkgs.spike;
    spike = callPackage ./spike {
      spike = basePkgs.spike;
    };
    gvsoc = callPackage ./gvsoc {
      inherit (basePkgs) cmake ninja makeWrapper lz4 zlib elfutils;
      inherit (basePkgs) python3;
    };
    bender0 = basePkgs.bender;
    bender = callPackage ./bender {
      inherit (basePkgs) rustPlatform gitMinimal;
    };

    # ── Synthesis ──────────────────────────────────────────────────────────────
    yosys0 = callPackage ./yosys {
      yosys = basePkgs.yosys;
      version = "0.62";
      rev = "v0.62";
      hash = "sha256-FzvdjdAURB5iCkGwsYY6A2wP/Je/IW4AOd4kVOEOeVc=";
    };
    yosys = callPackage ./yosys {
      yosys = basePkgs.yosys;
      useCmake = true;
    };
    yosys-full0 = yosysWithPlugins;
    yosys-full = yosys-full0;

    sv-lang9 = basePkgs.sv-lang_9;
    sv-lang10 = basePkgs.sv-lang_10;
    sv-lang11 = basePkgs.sv-lang;
    sv-lang = callPackage ./sv-lang {
      sv_lang = basePkgs.sv-lang;
    };
    slang = sv-lang;

    yosys-slang0 = callPackage ./yosys-slang { };
    yosys-slang = yosys-slang0;

    chisel7 = callPackage ./chisel {
      version = "7.13.0";
      hash = "sha256-L4k6KEUpHSqrp06fthwHfkyTyvpyiNF+iS2GpuQm9z8=";
    };
    chisel = callPackage ./chisel { };

    abc0 = basePkgs.abc-verifier;
    abc = callPackage ./abc {
      abc-verifier = basePkgs.abc-verifier;
    };
    sv2v0 = basePkgs.haskellPackages.sv2v;
    sv2v = callPackage ./sv2v { };

    circt1 = basePkgs.circt;
    circt = circt1;
    firrtl1 = basePkgs.firrtl;
    firrtl = callPackage ./firrtl {
      firrtl = basePkgs.firrtl;
    };

    # ── Waveform & debug ───────────────────────────────────────────────────────
    gtkwave3 = basePkgs.gtkwave;
    gtkwave = callPackage ./gtkwave { };
    surfer0 = basePkgs.surfer;
    surfer = surfer0;
    openocd0 = basePkgs.openocd;
    openocd = openocd0;

    # ── Linting, formatting & elaboration ─────────────────────────────────────
    verible0 = basePkgs.verible;
    verible = verible0;
    vhdl-ls0 = basePkgs.vhdl-ls;
    vhdl-ls = callPackage ./vhdl-ls {
      vhdl_ls = basePkgs.vhdl-ls;
    };
    surelog1 = basePkgs.surelog;
    surelog = surelog1;
    uhdm1 = basePkgs.uhdm;
    uhdm = uhdm1;

    # ── FPGA back-end ──────────────────────────────────────────────────────────
    nextpnr0 = basePkgs.nextpnr;
    nextpnr = nextpnr0;
    icestorm0 = basePkgs.icestorm;
    icestorm = icestorm0;
    trellis0 = basePkgs.trellis;
    trellis = trellis0;
    openfpgaloader0 = basePkgs.openfpgaloader;
    openfpgaloader = openfpgaloader0;
    vtr7 = callPackage ./vtr7 {
      version = "7";
      hash = "sha256-/tb/ZA3k30oijfLHOLuE9OAEVRqj3bkb2Yx6aXnZ3uA=";
    };
    vtr8 = callPackage ./vtr {
      version = "8.0.0";
      rev = "v8.0.0";
      fetchSubmodules = false;
      hash = "sha256-BDZcfG38b9jwqWDv2iOSKDAl+kbKobGXnZkYA9AZsJM=";
    };
    vtr9 = callPackage ./vtr {
      version = "9.0.0";
      rev = "v9.0.0";
      hash = "sha256-g5pDGy6A0e1gHFU64G7NcTAGiUj8vfyhJkQ3++4Y2yw=";
    };
    vtr = callPackage ./vtr { };
    fusesoc2 = basePkgs.fusesoc;
    fusesoc = callPackage ./fusesoc {
      fusesoc = basePkgs.fusesoc;
      pydantic = basePkgs.python3Packages.pydantic;
    };

    # ── Physical design ────────────────────────────────────────────────────────
    openroad26 = callPackage ./openroad {
      openroad = basePkgs.openroad;
      version = "26Q2";
      rev = "26Q2";
      hash = "sha256-dB9PfPlp6vZ9+Th8LJE65BW9YeuUL0G4JtjzQxg6UpQ=";
      patches = basePkgs.openroad.patches or [ ];
    };
    openroad = callPackage ./openroad {
      openroad = basePkgs.openroad;
    };
    openroad-flow-scripts26 = callPackage ./openroad-flow-scripts {
      version = "26Q2";
      rev = "26Q2";
      hash = "sha256-TJf/LGhRTCnfGq/7JGAX13ftvvdGX7UKs/qKRK5LLug=";
    };
    openroad-flow-scripts = callPackage ./openroad-flow-scripts { };
    openroad-flow-scripts-wrapper = callPackage ./openroad-flow-scripts-wrapper {
      inherit (basePkgs) makeWrapper gnumake tcl;
      inherit openroad openroad-flow-scripts klayout yosys-full yosys-slang;
    };
    orfs = openroad-flow-scripts-wrapper;
    klayout0 = callPackage ./klayout {
      klayout = basePkgs.klayout;
      version = "0.30.8";
      hash = "sha256-RjMH6hrc0jyCLgG1D6cztBp5Fb3W5HgTxVTfI2bxgCs=";
    };
    klayout = callPackage ./klayout {
      klayout = basePkgs.klayout;
    };
    magic-vlsi8 = callPackage ./magic-vlsi {
      magic-vlsi = basePkgs.magic-vlsi;
      version = "8.3.629";
      hash = "sha256-K/w2El2jkXN8qIa0kWvN8rCKWzjd8DcM3O6hb5UVQnw=";
    };
    magic-vlsi = callPackage ./magic-vlsi { magic-vlsi = basePkgs.magic-vlsi; };
    netgen-vlsi1 = basePkgs.netgen-vlsi;
    netgen-vlsi = netgen-vlsi1;

    # ── Analog & mixed-signal ─────────────────────────────────────────────────
    ngspice45 = basePkgs.ngspice;
    ngspice = ngspice45;
    xyce7 = basePkgs.xyce;
    xyce = xyce7;
    qucs-s25 = basePkgs.qucs-s;
    qucs-s = qucs-s25;
    xschem3 = basePkgs.xschem;
    xschem = callPackage ./xschem {
      xschem = basePkgs.xschem;
    };

    # ── Formal verification ────────────────────────────────────────────────────
    sby0 = basePkgs.sby;
    sby = sby0;
    eqy0 = callPackage ./eqy {
      version = "0.66";
      hash = "sha256-a2wc0OCVyl7N01g9MV3rnSay5c0jy8YCDB0d4eCNTr4=";
    };
    eqy = callPackage ./eqy { };
    mcy0 = basePkgs.mcy;
    mcy = mcy0;

    yices2 = basePkgs.yices;
    yices = yices2;
    boolector3 = basePkgs.boolector;
    boolector = boolector3;
    bitwuzla0 = basePkgs.bitwuzla;
    bitwuzla = bitwuzla0;
    cadical3 = basePkgs.cadical;
    cadical = cadical3;
    cryptominisat5 = basePkgs.cryptominisat;
    cryptominisat = cryptominisat5;
    z3-4 = basePkgs.z3;
    z3 = z3-4;
    cvc5-1 = basePkgs.cvc5;
    cvc5 = cvc5-1;

    aiger1 = basePkgs.aiger;
    aiger = callPackage ./aiger {
      aiger = basePkgs.aiger;
    };
    btor2tools0 = basePkgs.btor2tools;
    btor2tools = btor2tools0;

    # ── Microarchitecture modeling ─────────────────────────────────────────────
    flexfloat = callPackage ./flexfloat { };
    pyflexfloat = callPackage ./pyflexfloat {
      inherit flexfloat;
      inherit (basePkgs.python3Packages)
        buildPythonPackage
        setuptools
        setuptools-scm
        wheel
        numpy
        cffi
        ;
    };
    openram = callPackage ./openram {
      inherit (basePkgs.python3Packages)
        buildPythonPackage
        setuptools
        numpy
        scipy
        matplotlib
        scikit-learn
        coverage
        ;
    };
    openram-wrapper = callPackage ./openram-wrapper {
      inherit (basePkgs) makeWrapper python3;
      inherit openram cacti;
    };
    cacti6 = callPackage ./cacti {
      version = "6.5.0";
      rev = "v6.5.0";
      hash = "sha256-lYhaDQgQngoJs5GST+dTNPitVSmKhhivFtnzJH2XpdA=";
    };
    cacti7 = callPackage ./cacti {
      version = "unstable-2026-06-20";
      rev = "1ffd8dfb10303d306ecd8d215320aea07651e878";
      hash = "sha256-lrbrwKlaVvwEUDZA/n8I/zYNX3T8ltiBTYL94Ce5UQU=";
    };
    cacti = callPackage ./cacti { };

    dramsim3_1 = callPackage ./dramsim3 {
      version = "1.0.0";
      hash = "sha256-uErpWJEn6C9oKR6Bv1NOAC3ij3ne3A6BPtjtX7D8ZwE=";
    };
    dramsim3_ = callPackage ./dramsim3 { };
    mcpat1 = callPackage ./mcpat {
      version = "1.3.0";
      hash = "sha256-sr7H2vBOTyI59d3itVNqRVy1fR/83ZrTGl5s4I+g0Tw=";
    };
    mcpat = callPackage ./mcpat { };
    hotspot7 = callPackage ./hotspot {
      version = "7.0";
      hash = "sha256-AM8kTu0Rxpee3easDBKtu6+ld6lmpNVNO1z2jOQmhls=";
    };
    hotspot = callPackage ./hotspot { };

    # ── SoC frameworks ────────────────────────────────────────────────────────
    chipyard1 = callPackage ./chipyard {
      version = "1.14.0";
      rev = "1.14.0";
      hash = "sha256-vi0KRoioTPDdgZFITIOkAtMyWxuyAyMzwyqShGtVGZA=";
    };
    chipyard = callPackage ./chipyard { };

    # ── PULP Platform (ETH Zurich) ────────────────────────────────────────────
    # Branch-tracking source packages (no version suffix → update script targets HEAD).
    # Add a versioned alias (e.g. pulp-riscv-dbg0) once stable releases exist.
    pulp = {
      riscv-dbg = callPackage ./pulp {
        pname = "riscv-dbg";
        version = "unstable-2026-06-25";
        rev = "1cd764a82d7d49c5e8679fbb70b540b2e274bab9";
        hash = "sha256-hNLmuAEXW7EKWqIye3Ll062WtDxFkLLsjA6eJ6tT0Bc=";
        description = "PULP RISC-V debug module (JTAG DTM + DM)";
      };

      snitch = callPackage ./pulp {
        pname = "snitch_cluster";
        repo = "snitch_cluster";
        version = "unstable-2026-06-25";
        rev = "2fa38482c2c822bfbedfdfd87abb3ed45521646e";
        hash = "sha256-Vwk9rjimOcRVComL5G4xgrHqztwBwd95EXBrWTt7Ing=";
        description = "PULP Snitch: high-efficiency RISC-V many-core cluster";
      };

      cv32e40p = callPackage ./pulp {
        pname = "cv32e40p";
        version = "unstable-2026-06-25";
        rev = "e1891cd1f76082420c9035d82be55a7c7d6a80db";
        hash = "sha256-ifNMxQOaG5OM/qmvU5mPEjbhbmaWrXdvEDbqQySft6o=";
        description = "CORE-V CV32E40P embedded RISC-V core";
        license = lib.licenses.asl20;
      };
      riscv-llvm = callPackage ./pulp/riscv-llvm {
        inherit (basePkgs) llvmPackages cmake python3 ninja;
      };
      riscv-gcc = callPackage ./pulp/riscv-gcc {
        inherit (basePkgs)
          gmp
          mpfr
          libmpc
          isl
          zlib
          flex
          perl
          texinfo
          bison
          python3
          curl
          ;
      };
      riscv-spike = callPackage ./pulp/riscv-spike {
        inherit (basePkgs) dtc;
      };
    };

    # ── Python: HDL & co-simulation ───────────────────────────────────────────
    # Compose into python3.withPackages for actual use; excluded from env-var exports.
    ciel = callPackage ./ciel {
      inherit (basePkgs.python3Packages)
        buildPythonPackage
        poetry-core
        click
        pyyaml
        rich
        httpx
        pcpp
        zstandard
        ;
    };
    pyflooNoC = callPackage ./pyflooNoC {
      inherit (basePkgs.python3Packages)
        buildPythonPackage
        setuptools
        wheel
        mako
        hjson
        jsonref
        pylint
        pytest
        pygame
        pydantic
        ruamel-yaml
        click
        networkx
        matplotlib
        ;
    };
    cocotb2 = basePkgs.python3Packages.cocotb;
    cocotb = callPackage ./cocotb {
      cocotb = basePkgs.python3Packages.cocotb;
    };
    edalize0 = basePkgs.python3Packages.edalize;
    edalize = callPackage ./edalize {
      edalize = basePkgs.python3Packages.edalize;
    };
    amaranth0 = basePkgs.python3Packages.amaranth;
    amaranth = callPackage ./amaranth {
      amaranth = basePkgs.python3Packages.amaranth;
    };

    # ── Tool bundles ──────────────────────────────────────────────────────────
    simulation-tools = pkgs.symlinkJoin {
      name = "nixchip-simulation-tools";
      paths = [
        verilator
        sv-lang
        chisel
        systemc
        ghdl
        nvc
        iverilog
        gtkwave
        surfer
        verible
        spike
        vhdl-ls
      ];
    };

    formal-tools = pkgs.symlinkJoin {
      name = "nixchip-formal-tools";
      paths = [
        yosys-full
        sby
        eqy
        yices
        boolector
        bitwuzla
        cadical
        cryptominisat
        cvc5
        z3
        abc
        aiger
        btor2tools
        mcy
      ];
    };

    fpga-tools = pkgs.symlinkJoin {
      name = "nixchip-fpga-tools";
      paths = [
        yosys-full
        yosys-slang
        nextpnr
        icestorm
        trellis
        openfpgaloader
        sv2v
        vtr
        fusesoc
        openocd
      ]
      ++ optionalPackage "sby"
      ++ optionalPackage "symbiyosys";
    };

    physical-design-tools = pkgs.symlinkJoin {
      name = "nixchip-physical-design-tools";
      paths = [
        openroad
        openroad-flow-scripts
        openroad-flow-scripts-wrapper
        yosys-full
        circt
        firrtl
        klayout
        magic-vlsi
        netgen-vlsi
      ]
      ++ optionalUnfreePackage "espresso"
      ++ optionalPackage "surelog";
    };

    analog-tools = pkgs.symlinkJoin {
      name = "nixchip-analog-tools";
      paths = [
        ngspice
        xyce
        qucs-s
        xschem
      ];
    };

    memory-tools = pkgs.symlinkJoin {
      name = "nixchip-memory-tools";
      paths = [
        cacti
        dramsim3_
        mcpat
      ];
    };

    thermal-tools = pkgs.symlinkJoin {
      name = "nixchip-thermal-tools";
      paths = [
        hotspot
        dramsim3_
      ];
    };

    asic-tools = pkgs.symlinkJoin {
      name = "nixchip-asic-tools";
      paths = [
        physical-design-tools
        analog-tools
        memory-tools
        thermal-tools
        formal-tools
      ];
    };

    hardware-tools = pkgs.symlinkJoin {
      name = "nixchip-hardware-tools";
      paths = [
        simulation-tools
        fpga-tools
        asic-tools
        chipyard
        surelog
        uhdm
      ];
    };
  };
in
{
  nixchip = nixchipPackages;
}
// nixchipPackages
