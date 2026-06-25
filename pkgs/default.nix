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

  nixchipPackages = rec {

    # ── Simulators ─────────────────────────────────────────────────────────────
    verilator3 = callPackage ./verilator {
      version = "3.926";
      hash = "sha256-sbUmoeyUVyZniigixGKjLnHskiPvyMQFpeGo5PRMdRk=";
      doCheck = false;
    };
    verilator4 = callPackage ./verilator {
      version = "4.228";
      hash = "sha256-ToYad8cvBF3Mio5fuT4Ce4zXbWxFxd6smqB1TxvlHao=";
      doCheck = false;
    };
    verilator5 = basePkgs.verilator;
    verilator = verilator5;

    systemc2 = callPackage ./systemc {
      version = "2.3.4";
      hash = "sha256-CzjrkgvMRmL82omffz+bTI9JR900sdRmhZIhcyflSGo=";
    };
    systemc3 = callPackage ./systemc {
      version = "3.0.2";
      hash = "sha256-v/PcQu0m/7zyx2TtpZrLFbHtknahgVCkzcRi3lgrRGw=";
    };
    systemc = systemc3;

    ghdl6 = callPackage ./ghdl { ghdl = basePkgs.ghdl; };
    ghdl = ghdl6;
    nvc1 = basePkgs.nvc;
    nvc = nvc1;
    iverilog12 = basePkgs.iverilog;
    iverilog13 = callPackage ./iverilog { iverilog = basePkgs.iverilog; };
    iverilog = iverilog13;
    spike1 = basePkgs.spike;
    spike = spike1;

    # ── Synthesis ──────────────────────────────────────────────────────────────
    yosys0 = callPackage ./yosys { yosys = basePkgs.yosys; };
    yosys = yosys0;
    yosys-full0 = yosysWithPlugins;
    yosys-full = yosys-full0;

    sv-lang9 = basePkgs.sv-lang_9;
    sv-lang10 = basePkgs.sv-lang_10;
    sv-lang11 = basePkgs.sv-lang;
    sv-lang = sv-lang11;
    slang = sv-lang;

    yosys-slang0 = callPackage ./yosys-slang { };
    yosys-slang = yosys-slang0;

    chisel7 = callPackage ./chisel { };
    chisel = chisel7;

    abc0 = basePkgs.abc-verifier;
    abc = abc0;
    sv2v0 = basePkgs.haskellPackages.sv2v;
    sv2v = sv2v0;

    circt1 = basePkgs.circt;
    circt = circt1;
    firrtl1 = basePkgs.firrtl;
    firrtl = firrtl1;

    # ── Waveform & debug ───────────────────────────────────────────────────────
    gtkwave3 = basePkgs.gtkwave;
    gtkwave = gtkwave3;
    surfer0 = basePkgs.surfer;
    surfer = surfer0;
    openocd0 = basePkgs.openocd;
    openocd = openocd0;

    # ── Linting, formatting & elaboration ─────────────────────────────────────
    verible0 = basePkgs.verible;
    verible = verible0;
    vhdl-ls0 = basePkgs.vhdl-ls;
    vhdl-ls = vhdl-ls0;
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
    vtr7 = callPackage ./vtr7 { };
    vtr8 = callPackage ./vtr {
      version = "8.0.0";
      fetchSubmodules = false;
      hash = "sha256-BDZcfG38b9jwqWDv2iOSKDAl+kbKobGXnZkYA9AZsJM=";
    };
    vtr9 = callPackage ./vtr {
      version = "9.0.0";
      hash = "sha256-g5pDGy6A0e1gHFU64G7NcTAGiUj8vfyhJkQ3++4Y2yw=";
    };
    vtr = vtr9;
    fusesoc2 = basePkgs.fusesoc;
    fusesoc = fusesoc2;

    # ── Physical design ────────────────────────────────────────────────────────
    openroad26 = callPackage ./openroad {
      openroad = basePkgs.openroad;
      version = "26Q2";
      rev = "26Q2";
      hash = "sha256-dB9PfPlp6vZ9+Th8LJE65BW9YeuUL0G4JtjzQxg6UpQ=";
    };
    openroad = callPackage ./openroad { openroad = basePkgs.openroad; };
    openroad-flow-scripts26 = callPackage ./openroad-flow-scripts {
      version = "26Q2";
      rev = "26Q2";
      hash = "sha256-TJf/LGhRTCnfGq/7JGAX13ftvvdGX7UKs/qKRK5LLug=";
    };
    openroad-flow-scripts = callPackage ./openroad-flow-scripts { };
    klayout0 = callPackage ./klayout { klayout = basePkgs.klayout; };
    klayout = klayout0;
    magic-vlsi8 = callPackage ./magic-vlsi { magic-vlsi = basePkgs.magic-vlsi; };
    magic-vlsi = magic-vlsi8;
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
    xschem = xschem3;

    # ── Formal verification ────────────────────────────────────────────────────
    sby0 = basePkgs.sby;
    sby = sby0;
    eqy0 = callPackage ./eqy { };
    eqy = callPackage ./eqy {
      version = "0-unstable-2026-06-25";
      rev = "yosys-0.47";
      hash = "sha256-TH2wNvVi338JkxUsExUg2/JVdU3CWJ9MPKtitM/1Y00=";
    };
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

    aiger0 = basePkgs.aiger;
    aiger = aiger0;
    btor2tools0 = basePkgs.btor2tools;
    btor2tools = btor2tools0;

    # ── Microarchitecture modeling ─────────────────────────────────────────────
    cacti6 = callPackage ./cacti {
      version = "6.5.0";
      rev = "v6.5.0";
      hash = "sha256-lYhaDQgQngoJs5GST+dTNPitVSmKhhivFtnzJH2XpdA=";
    };
    cacti7 = callPackage ./cacti {
      version = "7.0-unstable-2026-06-20";
      rev = "1ffd8dfb10303d306ecd8d215320aea07651e878";
      hash = "sha256-lrbrwKlaVvwEUDZA/n8I/zYNX3T8ltiBTYL94Ce5UQU=";
    };
    cacti = cacti7;

    dramsim3-1 = callPackage ./dramsim3 { };
    dramsim3 = dramsim3-1;
    mcpat1 = callPackage ./mcpat { };
    mcpat = mcpat1;
    hotspot7 = callPackage ./hotspot { };
    hotspot = hotspot7;

    # ── SoC frameworks ────────────────────────────────────────────────────────
    chipyard1 = callPackage ./chipyard { };
    chipyard = chipyard1;

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
    };

    # ── Python: HDL & co-simulation ───────────────────────────────────────────
    # Compose into python3.withPackages for actual use; excluded from env-var exports.
    cocotb2 = basePkgs.python3Packages.cocotb;
    cocotb = cocotb2;
    edalize0 = basePkgs.python3Packages.edalize;
    edalize = edalize0;
    amaranth0 = basePkgs.python3Packages.amaranth;
    amaranth = amaranth0;

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
        dramsim3
        mcpat
      ];
    };

    thermal-tools = pkgs.symlinkJoin {
      name = "nixchip-thermal-tools";
      paths = [
        hotspot
        dramsim3
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
