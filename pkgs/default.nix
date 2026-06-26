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
      version = "unstable-2026-06-25";
      rev = "f0f1c44dd69a4dd17f923c9ca2f85dda8c006820";
      hash = "sha256-INVoGes/hJ1cpOS4H43uidB20DzJmMw85oCMyYqGFuo=";
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
      version = "unstable-2026-06-25";
      rev = "a50561f14dfe8447d8a507ce42924322921a11ce";
      hash = "sha256-KzuoA8xibRFdAjOTJ1pgqyaRAJ9DwOM790MPkE5AcTA=";
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
      version = "unstable-2026-06-25";
      rev = "2ac3c8a72acc826cc7ccddb87fce4c69552711d1";
      hash = "sha256-zD421ILhobLGJJIHfjgCFJcAGUGg7/LXFlyXkgZoS3Q=";
    };
    nvc1 = basePkgs.nvc;
    nvc = nvc1;
    iverilog12 = basePkgs.iverilog;
    iverilog13 = callPackage ./iverilog {
      iverilog = basePkgs.iverilog;
      version = "13.0";
      hash = "sha256-SfODx7K3UrDHMoKCbMFpxo4t9j9vG1oWF0RFS3dSUm4=";
    };
    iverilog = iverilog13;
    spike1 = basePkgs.spike;
    spike = callPackage ./spike {
      spike = basePkgs.spike;
      version = "unstable-2026-06-25";
      rev = "27731d158d7d9aa0f03b4b85fa684f5e3ac1a52e";
      hash = "sha256-t7yTD5VYWzV0zFHUmJB6RSGL9PRka+G8qjlHxjZ3Ago=";
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
      version = "unstable-2026-06-25";
      rev = "23aadd92ab0740bdaa256fbe1fecc23e417f77b6";
      hash = "sha256-vPYdRxTjR5ucWYq60R4hzA3HKk9w1TwO4F+2qqfjRZA=";
      useCmake = true;
    };
    yosys-full0 = yosysWithPlugins;
    yosys-full = yosys-full0;

    sv-lang9 = basePkgs.sv-lang_9;
    sv-lang10 = basePkgs.sv-lang_10;
    sv-lang11 = basePkgs.sv-lang;
    sv-lang = callPackage ./sv-lang {
      sv_lang = basePkgs.sv-lang;
      version = "unstable-2026-06-25";
      rev = "ab9bdf1ed140bbbd83d060e6c5dd24319b93986b";
      hash = "sha256-lMQCK0NlnDTEM68zsPNF4VVCrInyVYrcIlLyr276ZDQ=";
    };
    slang = sv-lang;

    yosys-slang0 = callPackage ./yosys-slang {
      version = "unstable-2026-06-23";
      rev = "3e0db86b102953ee2a56a64eddfe02a50273e565";
      hash = "sha256-mhAYkI0aYrttem6DE08bQ/bsITEaCzBd1MQBl0jQmCA=";
    };
    yosys-slang = yosys-slang0;

    chisel7 = callPackage ./chisel {
      version = "7.13.0";
      hash = "sha256-L4k6KEUpHSqrp06fthwHfkyTyvpyiNF+iS2GpuQm9z8=";
    };
    chisel = chisel7;

    abc0 = basePkgs.abc-verifier;
    abc = callPackage ./abc {
      abc-verifier = basePkgs.abc-verifier;
      version = "unstable-2026-06-25";
      rev = "3ce53c361f6017153a0f9bb3c91f4d04eb820fc2";
      hash = "sha256-9Sldy42mAfalA9Jqa752BCOTh+rtvu8nFeh1Nt0rJDk=";
    };
    sv2v0 = basePkgs.haskellPackages.sv2v;
    sv2v = callPackage ./sv2v {
      version = "unstable-2026-06-25";
      rev = "6662fa5da71f87797598060f17728b284b99a9fc";
      hash = "sha256-ziwLw1/S4wbnqml/AnN/yerOJJ3VOfRc3dZa8cmEaD0=";
    };

    circt1 = basePkgs.circt;
    circt = circt1;
    firrtl1 = basePkgs.firrtl;
    firrtl = callPackage ./firrtl {
      firrtl = basePkgs.firrtl;
      version = "unstable-2026-06-25";
      rev = "64731bbb16142a2b09ccbe74ab41b76b7a265869";
      hash = "sha256-djy81G2OGW/r0fGfluUa7+jL/6usD3Q015kuuH6DUE0=";
    };

    # ── Waveform & debug ───────────────────────────────────────────────────────
    gtkwave3 = basePkgs.gtkwave;
    gtkwave = callPackage ./gtkwave {
      version = "unstable-2026-06-25";
      rev = "7d7b4db9e2f5485afe2aeeab0ad112f5b6a9b94b";
      hash = "sha256-lEKW/OHk9xTqvf7UIcbZ3/toE6hWmed4dR/Ia21XY6I=";
    };
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
      version = "unstable-2026-06-25";
      rev = "873b2647712e2f6b1b775c8d555372120f386373";
      hash = "sha256-wN1MpYIyuaQ23poyB/0TbFgeaTFvALczCAb/tykzq8k=";
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
    vtr = callPackage ./vtr {
      version = "unstable-2026-06-25";
      rev = "d312fab8017ecfcd28a898eed9b2bc7aa68c145b";
      hash = "sha256-+wrXJ3+B300mYcEJVsRvGnLnlu4v85s7v1X9sXpv9Vc=";
    };
    fusesoc2 = basePkgs.fusesoc;
    fusesoc = callPackage ./fusesoc {
      fusesoc = basePkgs.fusesoc;
      version = "unstable-2026-06-25";
      rev = "f15e1c8a76815c4f391231dd0e743e2b683c6b45";
      hash = "sha256-f5ao99G/m//sdrIM1j6AT+kAt7/Zl8xvV8zM2XvCWAU=";
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
    xschem = callPackage ./xschem {
      xschem = basePkgs.xschem;
      version = "unstable-2026-06-25";
      rev = "c8b26a17d8d53ce7fbd9e7d45ab6bb03e75996e0";
      hash = "sha256-OpFMBiR7UZ4nLxcrD1hgrEvnuccwYgTy2mTHjA3/E0w=";
    };

    # ── Formal verification ────────────────────────────────────────────────────
    sby0 = basePkgs.sby;
    sby = sby0;
    eqy0 = callPackage ./eqy {
      version = "0.66";
      rev = "v0.66";
      hash = "sha256-a2wc0OCVyl7N01g9MV3rnSay5c0jy8YCDB0d4eCNTr4=";
    };
    eqy = callPackage ./eqy {
      version = "unstable-2026-06-25";
      rev = "8770b67d0bc802f17dbc9f2393d2dbc1f14c39ee";
      hash = "sha256-YMTWXLb9PMxps42ppkCvabPp+dDu6j+DlhQ7NQ73IoQ=";
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

    aiger1 = basePkgs.aiger;
    aiger = callPackage ./aiger {
      aiger = basePkgs.aiger;
      version = "unstable-2026-06-25";
      rev = "039ec1a2cc37d3093ac35c4b6df65336b346f409";
      hash = "sha256-evW5QSdXnT5rgxCRBYnvrE2zUAu/ZuH4Y2jHznXNAn4=";
    };
    btor2tools0 = basePkgs.btor2tools;
    btor2tools = btor2tools0;

    # ── Microarchitecture modeling ─────────────────────────────────────────────
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
    cacti = callPackage ./cacti {
      version = "unstable-2026-06-25";
      rev = "1ffd8dfb10303d306ecd8d215320aea07651e878";
      hash = "sha256-lrbrwKlaVvwEUDZA/n8I/zYNX3T8ltiBTYL94Ce5UQU=";
    };

    dramsim3-1 = callPackage ./dramsim3 {
      version = "1.0.0";
      hash = "sha256-uErpWJEn6C9oKR6Bv1NOAC3ij3ne3A6BPtjtX7D8ZwE=";
    };
    dramsim3 = dramsim3-1;
    mcpat1 = callPackage ./mcpat {
      version = "1.3.0";
      hash = "sha256-sr7H2vBOTyI59d3itVNqRVy1fR/83ZrTGl5s4I+g0Tw=";
    };
    mcpat = mcpat1;
    hotspot7 = callPackage ./hotspot {
      version = "7.0";
      hash = "sha256-AM8kTu0Rxpee3easDBKtu6+ld6lmpNVNO1z2jOQmhls=";
    };
    hotspot = hotspot7;

    # ── SoC frameworks ────────────────────────────────────────────────────────
    chipyard1 = callPackage ./chipyard {
      version = "1.14.0";
      hash = "sha256-vi0KRoioTPDdgZFITIOkAtMyWxuyAyMzwyqShGtVGZA=";
    };
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
    cocotb = callPackage ./cocotb {
      cocotb = basePkgs.python3Packages.cocotb;
      version = "unstable-2026-06-25";
      rev = "869c45921d7595668acafe44922e3bb5257d649d";
      hash = "sha256-G0rsGw//7SUh6ahFMZds8ymKf7fMDt1bIbJrjFW5rjU=";
    };
    edalize0 = basePkgs.python3Packages.edalize;
    edalize = callPackage ./edalize {
      edalize = basePkgs.python3Packages.edalize;
      version = "unstable-2026-06-25";
      rev = "5a4dc8c9cac28b6920ee5734b97409d379ffd382";
      hash = "sha256-ddvoq8FcSCPaaEw/eY6NemrF7RZrGnM4ZumpDbyCwPI=";
    };
    amaranth0 = basePkgs.python3Packages.amaranth;
    amaranth = callPackage ./amaranth {
      amaranth = basePkgs.python3Packages.amaranth;
      version = "unstable-2026-06-25";
      rev = "c9be3e4a9e932c25e361d0085af31c5b420efc41";
      hash = "sha256-0UfGuvfJTbF9enn6bb+75nKjLxsagQjnTL3UVKjqY+o=";
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
