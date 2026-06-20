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
    if basePkgs.yosys ? withPlugins then
      basePkgs.yosys.withPlugins (
        with basePkgs.yosys.allPlugins; lib.optionals (basePkgs.yosys.allPlugins ? ghdl) [ ghdl ]
      )
    else
      basePkgs.yosys;

  nixchipPackages = rec {
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

    yosys0 = basePkgs.yosys;
    yosys = basePkgs.yosys;
    yosys-full = yosysWithPlugins;
    yosys-full0 = yosys-full;

    sv-lang9 = basePkgs.sv-lang_9;
    sv-lang10 = basePkgs.sv-lang_10;
    sv-lang11 = basePkgs.sv-lang;
    sv-lang = sv-lang11;
    slang = sv-lang;

    yosys-slang0 = callPackage ./yosys-slang { };
    yosys-slang = yosys-slang0;

    chisel7 = callPackage ./chisel { };
    chisel = chisel7;

    verible0 = basePkgs.verible;
    verible = verible0;

    systemc2 = callPackage ./systemc {
      version = "2.3.4";
      hash = "sha256-CzjrkgvMRmL82omffz+bTI9JR900sdRmhZIhcyflSGo=";
    };

    systemc3 = callPackage ./systemc {
      version = "3.0.2";
      hash = "sha256-v/PcQu0m/7zyx2TtpZrLFbHtknahgVCkzcRi3lgrRGw=";
    };
    systemc = systemc3;

    ghdl6 = basePkgs.ghdl;
    ghdl = ghdl6;
    nvc1 = basePkgs.nvc;
    nvc = nvc1;

    surfer0 = basePkgs.surfer;
    surfer = surfer0;

    spike1 = basePkgs.spike;
    spike = spike1;

    vhdl-ls0 = basePkgs.vhdl-ls;
    vhdl-ls = vhdl-ls0;

    ngspice45 = basePkgs.ngspice;
    ngspice = ngspice45;
    xyce7 = basePkgs.xyce;
    xyce = xyce7;
    qucs-s25 = basePkgs.qucs-s;
    qucs-s = qucs-s25;
    xschem3 = basePkgs.xschem;
    xschem = xschem3;

    surelog1 = basePkgs.surelog;
    surelog = surelog1;
    uhdm1 = basePkgs.uhdm;
    uhdm = uhdm1;

    fusesoc2 = basePkgs.fusesoc;
    fusesoc = fusesoc2;

    # Python library packages — compose into a python3.withPackages env for actual use
    cocotb2 = basePkgs.python3Packages.cocotb;
    cocotb = cocotb2;
    edalize0 = basePkgs.python3Packages.edalize;
    edalize = edalize0;

    abc0 = basePkgs.abc-verifier;
    abc = abc0;

    sv2v0 = basePkgs.haskellPackages.sv2v;
    sv2v = sv2v0;

    vtr9 = callPackage ./vtr { };
    vtr = vtr9;

    eqy0 = callPackage ./eqy { };
    eqy = eqy0;

    netgen-vlsi1 = basePkgs.netgen-vlsi;
    netgen-vlsi = netgen-vlsi1;
    klayout0 = basePkgs.klayout;
    klayout = klayout0;
    magic-vlsi8 = basePkgs.magic-vlsi;
    magic-vlsi = magic-vlsi8;

    sby0 = basePkgs.sby;
    sby = sby0;
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

    aiger0 = basePkgs.aiger;
    aiger = aiger0;
    btor2tools0 = basePkgs.btor2tools;
    btor2tools = btor2tools0;
    mcy0 = basePkgs.mcy;
    mcy = mcy0;

    hotspot7 = callPackage ./hotspot { };
    hotspot = hotspot7;
    dramsim3-1 = callPackage ./dramsim3 { };
    dramsim3 = dramsim3-1;
    mcpat1 = callPackage ./mcpat { };
    mcpat = mcpat1;

    openroad26 = basePkgs.openroad;
    openroad = openroad26;

    openroad-flow-scripts26 = callPackage ./openroad-flow-scripts { };
    openroad-flow-scripts = openroad-flow-scripts26;

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

    chipyard1 = callPackage ./chipyard { };
    chipyard = chipyard1;

    circt1 = basePkgs.circt;
    circt = circt1;
    firrtl1 = basePkgs.firrtl;
    firrtl = firrtl1;

    simulation-tools = pkgs.symlinkJoin {
      name = "nixchip-simulation-tools";
      paths = [
        verilator
        sv-lang
        chisel
        systemc
        ghdl
        nvc
        basePkgs.iverilog
        basePkgs.gtkwave
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
        basePkgs.cvc5
        basePkgs.z3
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
        basePkgs.nextpnr
        basePkgs.icestorm
        basePkgs.trellis
        basePkgs.openfpgaloader
        sv2v
        vtr
        fusesoc
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
