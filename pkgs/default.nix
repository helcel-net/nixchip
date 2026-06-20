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
        basePkgs.iverilog
        basePkgs.gtkwave
        verible
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
      ]
      ++ optionalPackage "sby"
      ++ optionalPackage "symbiyosys";
    };

    asic-tools = pkgs.symlinkJoin {
      name = "nixchip-asic-tools";
      paths = [
        openroad
        openroad-flow-scripts
        yosys-full
        circt
        firrtl
        cacti
        basePkgs.klayout
        basePkgs.magic-vlsi
        basePkgs.netgen
        basePkgs.cvc5
        basePkgs.z3
      ]
      ++ optionalUnfreePackage "espresso"
      ++ optionalPackage "surelog";
    };

    hardware-tools = pkgs.symlinkJoin {
      name = "nixchip-hardware-tools";
      paths = [
        simulation-tools
        fpga-tools
        asic-tools
        chipyard
      ];
    };
  };
in
{
  nixchip = nixchipPackages;
}
// nixchipPackages
