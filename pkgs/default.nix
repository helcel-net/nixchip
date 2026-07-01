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

  githubSource =
    {
      owner,
      repo,
      rev,
      hash,
    }:
    pkgs.fetchFromGitHub {
      inherit
        owner
        repo
        rev
        hash
        ;
    };

  gitlabSource =
    {
      owner,
      repo,
      rev,
      hash,
    }:
    pkgs.fetchFromGitLab {
      inherit
        owner
        repo
        rev
        hash
        ;
    };

  taggedGithubSource = args: githubSource args // { tag = args.rev; };

  pinnedOverride =
    pkg: version: src:
    pkg.overrideAttrs (old: {
      inherit version src;
      passthru = (old.passthru or { }) // {
        nixchipUpdate = true;
      };
    });

  branchOverride =
    pkg: version: src:
    pkg.overrideAttrs (old: {
      inherit version src;
      passthru = (old.passthru or { }) // {
        nixchipUpdate = true;
      };
    });

  # Naming convention:
  # - Unsuffixed custom package attrs track upstream branch HEAD and use
  #   unstable-YYYY-MM-DD versions.
  # - Numbered attrs are fixed release slots for side-by-side tool versions.
  # - Upstream names ending in digits use a trailing underscore (e.g. z3_, cvc5_).
  nixchipPackages = rec {

    # ── Simulators ─────────────────────────────────────────────────────────────
    verilator3 = callPackage ./verilator {
      version = "3.926";
      hash = "sha256-sbUmoeyUVyZniigixGKjLnHskiPvyMQFpeGo5PRMdRk=";
    };
    verilator4 = callPackage ./verilator {
      version = "4.228";
      hash = "sha256-ToYad8cvBF3Mio5fuT4Ce4zXbWxFxd6smqB1TxvlHao=";
    };
    verilator5 = callPackage ./verilator {
      version = "5.048";
      hash = "sha256-xvqqgbW7L07+NBYzGN2KLhwir58ByShxo4VVPI3pgZk=";
    };
    verilator = callPackage ./verilator { };

    systemc2 = callPackage ./systemc {
      version = "2.3.4";
      hash = "sha256-CzjrkgvMRmL82omffz+bTI9JR900sdRmhZIhcyflSGo=";
    };
    systemc3 = callPackage ./systemc {
      version = "3.0.2";
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
    nvc1 = pinnedOverride basePkgs.nvc "1.21.1" (githubSource {
      owner = "nickg";
      repo = "nvc";
      rev = "r1.21.1";
      hash = "sha256-l4eGEDZrAXOhN5hPQLy2TcQEsQ+TTSNZVBFVwNsoQCo=";
    });
    iverilog12 = callPackage ./iverilog {
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
    spike1 = callPackage ./spike {
      spike = basePkgs.spike;
      version = "unstable-2024-09-21";
      rev = "de5094a1a901d77ff44f89b38e00fefa15d4018e";
      hash = "sha256-mAgR2VzDgeuIdmPEgrb+MaA89BnWfmNanOVidqn0cgc=";
    };
    spike = callPackage ./spike {
      spike = basePkgs.spike;
    };
    gvsoc = callPackage ./gvsoc {
      inherit (basePkgs)
        cmake
        ninja
        makeWrapper
        lz4
        zlib
        elfutils
        ;
      inherit (basePkgs) python3;
    };
    bender0 = callPackage ./bender {
      inherit (basePkgs) rustPlatform gitMinimal;
      version = "0.32.0";
      rev = "v0.32.0";
      hash = "sha256-Pyx68NTlCNTGKXdEGG9YML5E+vJlLHlPQjjbSV2uOsE=";
      cargoLockFile = ./bender/Cargo-0.lock;
    };
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
    yosys-full = yosysWithPlugins;

    sv-lang9 = pinnedOverride basePkgs.sv-lang_9 "9.1" (githubSource {
      owner = "MikePopoloski";
      repo = "slang";
      rev = "refs/tags/v9.1";
      hash = "sha256-IfRh6F6vA+nFa+diPKD2aMv9kRbvVIY80IqX0d+d5JA=";
    });
    sv-lang10 = pinnedOverride basePkgs.sv-lang_10 "10.0" (githubSource {
      owner = "MikePopoloski";
      repo = "slang";
      rev = "refs/tags/v10.0";
      hash = "sha256-rw+DztENuY+DiAhQR2oNN/dQJzrcP5neF3LoWnqri+c=";
    });
    sv-lang11 = pinnedOverride basePkgs.sv-lang "11.0" (githubSource {
      owner = "MikePopoloski";
      repo = "slang";
      rev = "refs/tags/v11.0";
      hash = "sha256-popHzwX0qwv2POAl7/qX3e//OwJRXGtSl9xogpSn2LI=";
    });
    sv-lang = callPackage ./sv-lang {
      sv_lang = basePkgs.sv-lang;
    };
    slang = sv-lang;

    yosys-slang = callPackage ./yosys-slang { };

    chisel7 = callPackage ./chisel {
      version = "7.13.0";
      hash = "sha256-L4k6KEUpHSqrp06fthwHfkyTyvpyiNF+iS2GpuQm9z8=";
    };
    chisel = callPackage ./chisel { };

    abc0 = pinnedOverride basePkgs.abc-verifier "0.62" (githubSource {
      owner = "yosyshq";
      repo = "abc";
      rev = "v0.62";
      hash = "sha256-T6Hj8zrr3XuI3Eh0I5rJI3+DAsuQIMtWEsaBJ8a5Cag=";
    });
    abc = callPackage ./abc {
      abc-verifier = basePkgs.abc-verifier;
    };
    sv2v0 = basePkgs.haskellPackages.sv2v.overrideAttrs (_old: {
      version = "0.0.13.1";
      src = pkgs.fetchurl {
        url = "mirror://hackage/sv2v-0.0.13.1.tar.gz";
        hash = "sha256-NDSSRynllL+boQe2Ucujki0QxqUeaow/TlMAG2oFu8U=";
      };
    });
    sv2v = callPackage ./sv2v { };

    circt1 = pinnedOverride basePkgs.circt "1.151.0" (githubSource {
      owner = "llvm";
      repo = "circt";
      rev = "firtool-1.151.0";
      hash = "sha256-2OF/VjTRXef3Pm25l7BrM/d5NBI1h0ocgoyIWHTu8K0=";
    });
    firrtl1 = callPackage ./firrtl {
      firrtl = basePkgs.firrtl;
      version = "1.5.3";
      hash = "sha256-7lv3I3TODEWiCWtKwk8Cl9EG8nVwZpz8T0yDjuL2AJg=";
    };
    firrtl = callPackage ./firrtl {
      firrtl = basePkgs.firrtl;
    };

    # ── Waveform & debug ───────────────────────────────────────────────────────
    gtkwave3 = pinnedOverride basePkgs.gtkwave "3.3.127" (
      pkgs.fetchurl {
        url = "mirror://sourceforge/gtkwave/gtkwave-gtk3-3.3.127.tar.gz";
        hash = "sha256-8Z2i20Oye7zGaXJYQ0UZRaaMOkziMlYuNB1vY7gLVeQ=";
      }
    );
    gtkwave = callPackage ./gtkwave { };
    surfer0 = pinnedOverride basePkgs.surfer "0.7.0" (gitlabSource {
      owner = "surfer-project";
      repo = "surfer";
      rev = "v0.7.0";
      hash = "sha256-WO0TWmUaKqUh+Cr75Hrxa2x4V9xZhzHY5PzlIRNUzZA=";
    });
    surfer = branchOverride basePkgs.surfer "unstable-2026-06-30" (gitlabSource {
      owner = "surfer-project";
      repo = "surfer";
      rev = "98287107b99fb03e50b11431413450f17c8d295a";
      hash = "sha256-m2Lk59cvlWTVL6xvk9zvfL52riub/4qRoLre7fyu1Uk=";
    });
    openocd0 = pinnedOverride basePkgs.openocd "0.12.0" (
      pkgs.fetchurl {
        url = "mirror://sourceforge/project/openocd/openocd/0.12.0/openocd-0.12.0.tar.bz2";
        hash = "sha256-ryVHiL6Yhh8r2RA/5uYKd07Jaow3R0Tu+Rl/YEMHWvo=";
      }
    );

    # ── Linting, formatting & elaboration ─────────────────────────────────────
    verible0 = pinnedOverride basePkgs.verible "0.0.4023" (githubSource {
      owner = "chipsalliance";
      repo = "verible";
      rev = "refs/tags/v0.0-4023-gc1271a00";
      hash = "sha256-N+yjRcVxFI56kP3zq+qFHNXZLTtVnQaVnseZS13YN0s=";
    });
    verible = branchOverride basePkgs.verible "unstable-2026-06-30" (githubSource {
      owner = "chipsalliance";
      repo = "verible";
      rev = "b33cc90019824a8a157f2d5a042912a4b7d67391";
      hash = "sha256-r++v5wD0+FBAlPV0/sUomqO4BIxUPAqFS2p26d0iFzo=";
    });
    vhdl-ls0 = callPackage ./vhdl-ls {
      vhdl_ls = basePkgs.vhdl-ls;
      version = "0.87.1";
      hash = "sha256-+7kjRjRtsb038xw0x+yojhWVChvkBz6kTlqSc3rTwXE=";
    };
    vhdl-ls = callPackage ./vhdl-ls {
      vhdl_ls = basePkgs.vhdl-ls;
    };
    surelog1 = pinnedOverride basePkgs.surelog "1.86" (githubSource {
      owner = "chipsalliance";
      repo = "surelog";
      rev = "refs/tags/v1.86";
      hash = "sha256-EEhaYimyzOgQB7dxbbTfsa7APC6SlFkz9ah9BLcKDq4=";
    });
    surelog = branchOverride basePkgs.surelog "unstable-2026-07-01" (githubSource {
      owner = "chipsalliance";
      repo = "surelog";
      rev = "d3492266357fb49fc4ee75f5e9268088c70096ec";
      hash = "sha256-CIozphxpZ0omcPx3bpI1MpDG6+TkLe6T/v8NnR1OIxk=";
    });
    uhdm1 = pinnedOverride basePkgs.uhdm "1.86" (githubSource {
      owner = "chipsalliance";
      repo = "UHDM";
      rev = "refs/tags/v1.86";
      hash = "sha256-f7QJJEP/jL69DdMJOL5WQdDZU+kBnnLi2eX37AoaXls=";
    });
    uhdm = branchOverride basePkgs.uhdm "unstable-2026-07-01" (githubSource {
      owner = "chipsalliance";
      repo = "UHDM";
      rev = "fc89c272c34b7cbc294c9cd4e3373657eb51e0ef";
      hash = "sha256-2KTDC/z2E4SNvdO7FmoJ92gVMvDnU+Grvd7PBQvPSVk=";
    });

    # ── FPGA back-end ──────────────────────────────────────────────────────────
    nextpnr0 = pinnedOverride basePkgs.nextpnr "0.10" (taggedGithubSource {
      owner = "YosysHQ";
      repo = "nextpnr";
      rev = "refs/tags/nextpnr-0.10";
      hash = "sha256-goHHEvkBw+9s3RHGfQtRaueXRBnoI14TmfGmb+1WPAY=";
    });
    nextpnr = branchOverride basePkgs.nextpnr "unstable-2026-06-30" (taggedGithubSource {
      owner = "YosysHQ";
      repo = "nextpnr";
      rev = "2b560ad0ccc6e7e93ad8bd6cb0f88f925bbb314b";
      hash = "sha256-NOAj3/OCmybEnbhdL+pzVD/JBmnXZ0UyqVaEc4q6R0A=";
    });
    icestorm0 = pinnedOverride basePkgs.icestorm "unstable-2025-06-03" (githubSource {
      owner = "YosysHQ";
      repo = "icestorm";
      rev = "f31c39cc2eadd0ab7f29f34becba1348ae9f8721";
      hash = "sha256-SLSxqgVsYMUxv8YjY1iRLnVFiIAhk/GKmZr4Ido0A3o=";
    });
    trellis0 = basePkgs.trellis.overrideAttrs (_old: {
      version = "unstable-2025-01-30";
    });
    openfpgaloader0 = pinnedOverride basePkgs.openfpgaloader "1.1.1" (githubSource {
      owner = "trabucayre";
      repo = "openFPGALoader";
      rev = "v1.1.1";
      hash = "sha256-VQM3swGAvuLnqKjjUEXJlQp1nGH9M1ydEKQUV/5xiwM=";
    });
    openfpgaloader = branchOverride basePkgs.openfpgaloader "unstable-2026-06-30" (githubSource {
      owner = "trabucayre";
      repo = "openFPGALoader";
      rev = "d90fa0ca85763f0d91de89c17c55a20fc35fba94";
      hash = "sha256-p+MYdR0XNaKJH8MiDsROootu+frdibkH2e9YTLuog6s=";
    });
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
    fusesoc2 = callPackage ./fusesoc {
      fusesoc = basePkgs.fusesoc;
      pydantic = basePkgs.python3Packages.pydantic;
      version = "2.4.6";
      hash = "sha256-d4ro802pkpZqm5MYg3Yplu8IhKhVEqR5MfvrCsLcdYU=";
    };
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
      inherit
        openroad
        openroad-flow-scripts
        klayout
        yosys-full
        yosys-slang
        ;
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
    netgen-vlsi1 = pinnedOverride basePkgs.netgen-vlsi "1.5.322" (githubSource {
      owner = "RTimothyEdwards";
      repo = "netgen";
      rev = "refs/tags/1.5.321";
      hash = "sha256-jq7JvChnNSeZf7OrV9EIiOPv5nDqs6r8L9TY6k4vGXc=";
    });

    # ── Analog & mixed-signal ─────────────────────────────────────────────────
    ngspice45 = pinnedOverride basePkgs.ngspice "45" (
      pkgs.fetchurl {
        url = "mirror://sourceforge/ngspice/ngspice-45.tar.gz";
        hash = "sha256-8arYq6woKKe3HaZkEd6OQGUk518wZuRnVUOcSQRC1zQ=";
      }
    );
    xyce7 = basePkgs.xyce.overrideAttrs (_old: {
      version = "7.10.0";
    });
    qucs-s25 = pinnedOverride basePkgs.qucs-s "25.2.0" (githubSource {
      owner = "ra3xdh";
      repo = "qucs_s";
      rev = "refs/tags/25.2.0";
      hash = "sha256-U5XLjWKOXNjgYtlccNsPT1nUnEGi3NhkJ36jan2OSAw=";
    });
    qucs-s = branchOverride basePkgs.qucs-s "unstable-2026-07-01" (githubSource {
      owner = "ra3xdh";
      repo = "qucs_s";
      rev = "1239336192adee7593ded74db844db0f88f0f03b";
      hash = "sha256-Syti/maOCYi/JwUkOhGwCvluhz7BFRuQcnVs1lmC0X8=";
    });
    xschem3 = callPackage ./xschem {
      xschem = basePkgs.xschem;
      version = "3.4.7";
      hash = "sha256-ye97VJQ+2F2UbFLmGrZ8xSK9xFeF+Yies6fJKurPOD0=";
    };
    xschem = callPackage ./xschem {
      xschem = basePkgs.xschem;
    };

    # ── Formal verification ────────────────────────────────────────────────────
    sby0 = pinnedOverride basePkgs.sby "0.61" (githubSource {
      owner = "YosysHQ";
      repo = "sby";
      rev = "refs/tags/v0.61";
      hash = "sha256-pFtSXg8DiN//jkZJyAIJ/jpVvu1OwwfAAXSrrmCZ3SQ=";
    });
    sby = branchOverride basePkgs.sby "unstable-2026-06-30" (githubSource {
      owner = "YosysHQ";
      repo = "sby";
      rev = "d3e72d26e8634bca4ca16f3e4d84331481f06ab6";
      hash = "sha256-VVnXRJLiGYId4BQX4WThwEkuWOMPwpaXFlkl1pbqkWs=";
    });
    eqy0 = callPackage ./eqy {
      version = "0.66";
      hash = "sha256-a2wc0OCVyl7N01g9MV3rnSay5c0jy8YCDB0d4eCNTr4=";
    };
    eqy = callPackage ./eqy { };
    mcy0 = pinnedOverride basePkgs.mcy "0.66" (githubSource {
      owner = "YosysHQ";
      repo = "mcy";
      rev = "v0.66";
      hash = "sha256-ieexePa/QLN/ej/+JO1TB0YUo5CD+K+EtrGqKdayDoo=";
    });

    yices2 = pinnedOverride basePkgs.yices "2.7.0" (githubSource {
      owner = "SRI-CSL";
      repo = "yices2";
      rev = "yices-2.7.0";
      hash = "sha256-siyepgxqKWRyO4+SB95lmhJ98iDubk0R0ErEJdSsM8o=";
    });
    boolector3 = pinnedOverride basePkgs.boolector "3.2.4" (githubSource {
      owner = "boolector";
      repo = "boolector";
      rev = "refs/tags/3.2.4";
      hash = "sha256-CKhaPaWUB6Fz0LfnCl81LVmTebCWzTvZLKeC0KH3by4=";
    });
    bitwuzla0 = pinnedOverride basePkgs.bitwuzla "0.9.1" (githubSource {
      owner = "bitwuzla";
      repo = "bitwuzla";
      rev = "refs/tags/0.9.1";
      hash = "sha256-3uStLdDFhXVgqzremUPRbxPUcl0IqVg5MRLltgm8rCA=";
    });
    cadical3 = pinnedOverride basePkgs.cadical "3.0.0" (githubSource {
      owner = "arminbiere";
      repo = "cadical";
      rev = "rel-3.0.0";
      hash = "sha256-pymbSC6bwQQ0YCtJd3xWZiC22UEkFiKSLObSOnoQj9I=";
    });
    cryptominisat5 = pinnedOverride basePkgs.cryptominisat "5.11.21" (githubSource {
      owner = "msoos";
      repo = "cryptominisat";
      rev = "5.11.21";
      hash = "sha256-8oH9moMjQEWnQXKmKcqmXuXcYkEyvr4hwC1bC4l26mo=";
    });
    z3_4 = pinnedOverride basePkgs.z3 "4.16.0" (githubSource {
      owner = "Z3Prover";
      repo = "z3";
      rev = "z3-4.16.0";
      hash = "sha256-DnhX3kxggnFmyYwXEPBsBA1rh4oor1oIJR5TMJk/jvc=";
    });
    z3_ = branchOverride basePkgs.z3 "unstable-2026-07-01" (githubSource {
      owner = "Z3Prover";
      repo = "z3";
      rev = "652402fa1f39b7b8ad06c78c10c0b4a5cf2f016a";
      hash = "sha256-OJOnu5cYFj5z+L5hzVV3ZuOWRUgSp/spRoDZnXv7PnM=";
    });
    cvc5_1 = pinnedOverride basePkgs.cvc5 "1.3.4" (githubSource {
      owner = "cvc5";
      repo = "cvc5";
      rev = "cvc5-1.3.4";
      hash = "sha256-PZcOArSTyJzyd2DKT8K0aFC4RlVXgTCnkoU0f08KPfY=";
    });
    cvc5_ = branchOverride basePkgs.cvc5 "unstable-2026-07-01" (githubSource {
      owner = "cvc5";
      repo = "cvc5";
      rev = "073f335e7282295f5b7e0dede1791a9c33d69236";
      hash = "sha256-KFf5xxYOL0HND1JignzrHPX4lWmyR11NgdpbsXFW2Ko=";
    });

    aiger1 = callPackage ./aiger {
      aiger = basePkgs.aiger;
      version = "1.9.20";
      hash = "sha256-ggkxITuD8phq3VF6tGc/JWQGBhTfPxBdnRobKswYVa4=";
    };
    aiger = callPackage ./aiger {
      aiger = basePkgs.aiger;
    };
    btor2tools0 = pinnedOverride basePkgs.btor2tools "unstable-2025-09-18" (githubSource {
      owner = "boolector";
      repo = "btor2tools";
      rev = "d33c73ff1d173f1bfac8ba6b1c6d68ba62c55f8e";
      hash = "sha256-RVjZ5HM2yQ3eAICFuzwvNeQDXzWzzSiCCslIWMJi6U8=";
    });

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
        inherit (basePkgs)
          llvmPackages
          cmake
          python3
          ninja
          ;
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
    cocotb2 = callPackage ./cocotb {
      cocotb = basePkgs.python3Packages.cocotb;
      version = "2.0.1";
      hash = "sha256-LXQNqFlvP+WBaDGWPs5+BXBtW2dhDu+v+7lR/AMG21M=";
    };
    cocotb = callPackage ./cocotb {
      cocotb = basePkgs.python3Packages.cocotb;
    };
    edalize0 = callPackage ./edalize {
      edalize = basePkgs.python3Packages.edalize;
      version = "0.6.1";
      hash = "sha256-5c3Szq0tXQdlyzFTFCla44qB/O6RK8vezVOaFOv8sw4=";
    };
    edalize = callPackage ./edalize {
      edalize = basePkgs.python3Packages.edalize;
    };
    amaranth0 = callPackage ./amaranth {
      amaranth = basePkgs.python3Packages.amaranth;
      version = "0.5.8";
      hash = "sha256-hqMgyQJRz1/5C9KB3nAI2RKPZXZUl3zhfZbk9M1hTxs=";
    };
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
        nvc1
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
        yices2
        boolector3
        bitwuzla0
        cadical3
        cryptominisat5
        cvc5_
        z3_
        abc
        aiger
        btor2tools0
        mcy0
      ];
    };

    fpga-tools = pkgs.symlinkJoin {
      name = "nixchip-fpga-tools";
      paths = [
        yosys-full
        yosys-slang
        nextpnr
        icestorm0
        trellis0
        openfpgaloader
        sv2v
        vtr
        fusesoc
        openocd0
      ]
      ++ optionalPackage "symbiyosys";
    };

    physical-design-tools = pkgs.symlinkJoin {
      name = "nixchip-physical-design-tools";
      paths = [
        openroad
        openroad-flow-scripts
        openroad-flow-scripts-wrapper
        yosys-full
        circt1
        firrtl
        klayout
        magic-vlsi
        netgen-vlsi1
      ]
      ++ optionalUnfreePackage "espresso";
    };

    analog-tools = pkgs.symlinkJoin {
      name = "nixchip-analog-tools";
      paths = [
        ngspice45
        xyce7
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
