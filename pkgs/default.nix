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
    name:
    let
      package = builtins.getAttr name basePkgs;
      inherit (basePkgs) config;
    in
    lib.optionals (config.allowUnfree or false || (config.allowUnfreePredicate or (_: false)) package) [
      package
    ];

  # nixpkgs' release yosys with nixpkgs' GHDL plugin, as a matched pair. It is
  # taken from a nixpkgs instance without this overlay: inside the overlay the
  # plugin would resolve `yosys` to the HEAD build, whose RTLIL API it predates.
  pristinePkgs = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    inherit (pkgs) config;
  };
  yosysWithPlugins =
    let
      inherit (pristinePkgs) yosys;
      base =
        if yosys ? withPlugins then
          yosys.withPlugins (with yosys.allPlugins; lib.optionals (yosys.allPlugins ? ghdl) [ ghdl ])
        else
          yosys;
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
      fetchSubmodules ? false,
    }:
    pkgs.fetchFromGitHub {
      inherit
        owner
        repo
        rev
        hash
        fetchSubmodules
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
        nixchipCI = true;
        nixchipUpdate = true;
      };
    });

  # buildRustPackage reads cargoHash from its original args, so overrideAttrs
  # cannot reach it. src, however, comes from finalAttrs and does follow an
  # override -- so bumping a rev re-vendors against the new source while still
  # checking against the stale hash. Re-point the vendor FOD's hash instead.
  # cargoHash is passed as a named attr so scripts/update-packages.sh can find
  # and rewrite it with the same block-scoped sed it uses for rev and hash.
  cargoVendorOverride =
    { cargoHash }:
    pkg:
    pkg.overrideAttrs (old: {
      cargoDeps = old.cargoDeps.overrideAttrs (o: {
        vendorStaging = o.vendorStaging.overrideAttrs { outputHash = cargoHash; };
      });
    });

  branchOverride =
    pkg: version: src:
    pkg.overrideAttrs (old: {
      inherit version src;
      passthru = (old.passthru or { }) // {
        nixchipCI = true;
        nixchipUpdate = true;
      };
    });

  # nextpnr's gowin chipdb generation needs apycula >= 0.33 (GW5A/GW5AT
  # devices); nixpkgs still ships 0.32. Drop when nixpkgs catches up.
  #
  # The overlay exports this repo's HEAD icestorm/trellis under nixpkgs' names;
  # nextpnr's chip databases are generated from them and break against HEAD
  # databases (nextpnr 0.11.1: KeyError 'FILTERIN'), so take nixpkgs' own.
  # nextpnrHeadBase below swaps in our HEAD trellis deliberately.
  nextpnrBase = basePkgs.nextpnr.override {
    inherit (pristinePkgs) icestorm trellis;
    python3Packages = basePkgs.python3Packages // {
      apycula = basePkgs.python3Packages.apycula.overridePythonAttrs (old: rec {
        version = "0.33";
        src = basePkgs.python3Packages.fetchPypi {
          pname = "apycula";
          inherit version;
          hash = "sha256-njVvWr8sH2UABEDxvTSDXBuTgaZNIHfphwiHB14IbhY=";
        };
      });
    };
  };

  # prjtrellis-db is a submodule of prjtrellis, so a fetchSubmodules src
  # replaces nixpkgs' separate database_src; that lets the update script, which
  # only edits `src`, track trellis. Its build version comes from git describe
  # in nixpkgs, so feed the attr version instead.
  trellisFromSubmodules = finalAttrs: _old: {
    srcs = null;
    sourceRoot = null;
    cmakeFlags = [
      "-DCURRENT_GIT_VERSION=${finalAttrs.version}"
      "-DCMAKE_INSTALL_DATADIR=${placeholder "out"}/share"
    ];
    # Boost >= 1.89 ships boost_system header-only, so releases up to 1.4
    # fail asking for its library; upstream dropped it after 1.4.
    postPatch = ''
      substituteInPlace libtrellis/CMakeLists.txt \
        --replace-quiet "program_options system)" "program_options)"
    '';
    preConfigure = ''
      cd libtrellis
    '';
  };

  # bsc vendors yices as a submodule; nixpkgs fetches a per-release
  # yices-src tarball instead, which a src-only update cannot follow.
  bluespecFromSubmodules = _old: {
    postUnpack = ''
      chmod -R +rwX $sourceRoot/src/vendor/yices/v2.6/yices2
    '';
  };

  # Upstream moved qucs-s-spar-viewer into a git submodule (fetchSubmodules is
  # needed on the src). qucsator_rf looks for bison with NO_DEFAULT_PATH
  # against a hardcoded FHS path list, so having it in nativeBuildInputs is not
  # enough -- BISON_DIR is the only way to point it at the store. Its gperf
  # hash generation shells out to dos2unix, which nixpkgs does not carry.
  qucsSFixes = old: {
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DBISON_DIR=${pkgs.bison}/bin" ];
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.dos2unix ];
  };

  z3Fixes = old: {
    # Upstream rewrote z3.pc.cmake.in after 4.16.0, so nixpkgs'
    # fix-pkg-config-paths.patch no longer applies. Carry a rebased copy
    # until nixpkgs moves past 4.16.0.
    patches = [ ./z3/fix-pkg-config-paths.patch ];
    # z3's own build embeds its CMake project version (e.g. "4.17.0") in
    # `z3 --version`, unrelated to our "unstable-YYYY-MM-DD" tracking
    # version, so versionCheckHook can never match it for this attr.
    doInstallCheck = false;
    # Newer z3 leaves a libz3.so symlink beside the python bindings pointing
    # at the absolute build directory. It still resolves inside the sandbox,
    # so it is not a broken link at fixup time -- noBrokenSymlinks rejects it
    # for pointing into /build, which is where it will dangle afterwards.
    # Match on the target rather than on brokenness, and repoint into $lib.
    postFixup = ''
      for o in $outputs; do
        for l in $(find "''${!o}" -type l 2>/dev/null); do
          case "$(readlink "$l")" in
            /build/*) ln -sf "$lib/lib/$(basename "$(readlink "$l")")" "$l" ;;
          esac
        done
      done
    ''
    + (old.postFixup or "");
  };

  # nextpnr HEAD outgrows nixpkgs' chip databases: ecp5 import calls
  # pytrellis APIs newer than nixpkgs' trellis snapshot (use our branch
  # trellis), and gatemate checks the prjpeppercorn database version that
  # nixpkgs hard-wires. Bump the peppercorn tag when nextpnr reports a
  # "chip database mismatch".
  nextpnrHeadBase =
    (nextpnrBase.override { trellis = nixchipPackages.trellis; }).overrideAttrs
      (old: {
        cmakeFlags = map (
          flag:
          if lib.hasPrefix "-DHIMBAECHEL_PEPPERCORN_PATH" flag then
            "-DHIMBAECHEL_PEPPERCORN_PATH=${
              pkgs.fetchFromGitHub {
                owner = "YosysHQ";
                repo = "prjpeppercorn";
                tag = "v1.14";
                hash = "sha256-cQgSgiBvrjkqJcC5g0ZlcGwTkzeOn3vR9N/aUHda6Jk=";
              }
            }"
          else
            flag
        ) old.cmakeFlags;
      });

  # nixpkgs marks or-tools broken under the default python3 (3.14: its pinned
  # pybind 2.13 has no 3.14 support), which blocks openroad from evaluating.
  # Build or-tools with python 3.13 until nixpkgs moves to pybind 3.
  # With python 3.13, or-tools' own ctest still fails a python-contrib
  # dependency check that openroad never touches (it links the C++ libraries
  # only), so checks are skipped rather than fixed.
  #
  # OpenROAD vendors slang, whose `fmt::format` calls need <fmt/format.h>
  # since fmt 12.2 (nixpkgs' fmt-12.2.patch for sv-lang does the same swap,
  # but its hunks only fit slang 11, not the older vendored copies).
  openroadBase =
    (basePkgs.openroad.override {
      or-tools = (basePkgs.or-tools.override { python3 = basePkgs.python313; }).overrideAttrs (_: {
        doCheck = false;
      });
    }).overrideAttrs
      (old: {
        postPatch = (old.postPatch or "") + ''
          slang=third-party/slang-elab/third_party/slang
          if [ -d "$slang" ]; then
            find "$slang" -type f \( -name '*.h' -o -name '*.cpp' \) -exec sed -i \
              -e 's|<fmt/core.h>|<fmt/format.h>|' -e 's|"fmt/core.h"|<fmt/format.h>|' {} +
          fi
        '';
      });

  # Naming convention:
  # - Attrs ending in _N are fixed major-version slots for side-by-side tool
  #   versions (systemc_2, verilator_5, dramsim3_1): the digits after the
  #   final underscore are the pinned major.
  # - Every other attr tracks the latest upstream: branch HEAD with
  #   unstable-YYYY-MM-DD versions, or the latest release where
  #   nixchipUpdateFlags pins a tag shape (gem5, circt). Trailing digits in
  #   such names are simply part of the upstream name (gem5, ramulator2,
  #   booksim2, z3).
  nixchipPackages = rec {

    # ── Simulators ─────────────────────────────────────────────────────────────
    verilator_3 = callPackage ./verilator {
      version = "3.926";
      hash = "sha256-sbUmoeyUVyZniigixGKjLnHskiPvyMQFpeGo5PRMdRk=";
    };
    verilator_4 = callPackage ./verilator {
      version = "4.228";
      hash = "sha256-ToYad8cvBF3Mio5fuT4Ce4zXbWxFxd6smqB1TxvlHao=";
    };
    verilator_5 = callPackage ./verilator {
      version = "5.048";
      hash = "sha256-xvqqgbW7L07+NBYzGN2KLhwir58ByShxo4VVPI3pgZk=";
    };
    verilator = callPackage ./verilator { };

    systemc_2 = callPackage ./systemc {
      version = "2.3.4";
      hash = "sha256-CzjrkgvMRmL82omffz+bTI9JR900sdRmhZIhcyflSGo=";
    };
    systemc_3 = callPackage ./systemc {
      version = "3.0.2";
      hash = "sha256-v/PcQu0m/7zyx2TtpZrLFbHtknahgVCkzcRi3lgrRGw=";
    };
    systemc = callPackage ./systemc {
      cxxStandard = "17";
    };

    ghdl_6 = callPackage ./ghdl {
      ghdl = basePkgs.ghdl;
      version = "6.0.0";
      rev = "v6.0.0";
      hash = "sha256-Q5lAWMa1SFjoIJTdWlHSbS4Cg5RYWiej8F05Xrz9ArY=";
    };
    ghdl = callPackage ./ghdl {
      ghdl = basePkgs.ghdl;
    };
    nvc_1 = pinnedOverride basePkgs.nvc "1.23.1" (githubSource {
      owner = "nickg";
      repo = "nvc";
      rev = "r1.23.1";
      hash = "sha256-J049HgwmBG9CqQNiP8sjf4/Yyvtngx2S4cqHBnveSVY=";
    });
    iverilog_12 = callPackage ./iverilog {
      iverilog = basePkgs.iverilog;
      version = "12.0";
      hash = "sha256-J9hedSmC6mFVcoDnXBtaTXigxrSCFa2AhhFd77ueo7I=";
    };
    iverilog_13 = callPackage ./iverilog {
      iverilog = basePkgs.iverilog;
      version = "13.0";
      hash = "sha256-SfODx7K3UrDHMoKCbMFpxo4t9j9vG1oWF0RFS3dSUm4=";
    };
    iverilog = callPackage ./iverilog { iverilog = basePkgs.iverilog; };
    sail-riscv_0 = pinnedOverride basePkgs.sail-riscv "0.12" (githubSource {
      owner = "riscv";
      repo = "sail-riscv";
      rev = "0.12";
      hash = "sha256-pi/XP6+NX/wNpBESmnEg2d5cppMpMwFripDPk9vTx9I=";
    });
    # v1.1.0 (2021) predates GCC no longer including <cstdint> transitively.
    spike_1 =
      (callPackage ./spike {
        spike = basePkgs.spike;
        version = "1.1.0";
        rev = "v1.1.0";
        hash = "sha256-4D2Fezej0ioOOupw3kgMT5VLs+/jXQjwvek6v0AVMzI=";
      }).overrideAttrs
        (_: {
          env.CXXFLAGS = "-O2 -include cstdint";
        });
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
    bender_0 = callPackage ./bender {
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
    yosys_0 = callPackage ./yosys {
      yosys = basePkgs.yosys;
      version = "0.71";
      rev = "v0.71";
      hash = "sha256-QURMzxiADHu0FDygmfHYHyS4ueZFyCTnxVjn4a5OSCo=";
    };
    yosys = callPackage ./yosys {
      yosys = basePkgs.yosys;
      useCmake = true;
    };
    yosys-full = yosysWithPlugins;

    sv-lang_9 = pinnedOverride basePkgs.sv-lang_9 "9.1" (githubSource {
      owner = "MikePopoloski";
      repo = "slang";
      rev = "v9.1";
      hash = "sha256-IfRh6F6vA+nFa+diPKD2aMv9kRbvVIY80IqX0d+d5JA=";
    });
    sv-lang_10 = pinnedOverride basePkgs.sv-lang_10 "10.0" (githubSource {
      owner = "MikePopoloski";
      repo = "slang";
      rev = "v10.0";
      hash = "sha256-rw+DztENuY+DiAhQR2oNN/dQJzrcP5neF3LoWnqri+c=";
    });
    sv-lang_11 = pinnedOverride basePkgs.sv-lang "11.0" (githubSource {
      owner = "MikePopoloski";
      repo = "slang";
      rev = "v11.0";
      hash = "sha256-popHzwX0qwv2POAl7/qX3e//OwJRXGtSl9xogpSn2LI=";
    });
    sv-lang_12 = callPackage ./sv-lang {
      sv_lang = basePkgs.sv-lang;
      version = "12.1";
      rev = "v12.1";
      hash = "sha256-QVMlxrGPy+cxpQW5/v+JmC+IJ05cHHpaKCzvIdaxTHE=";
    };
    sv-lang = callPackage ./sv-lang {
      sv_lang = basePkgs.sv-lang;
    };
    slang = sv-lang;

    yosys-slang = callPackage ./yosys-slang { };

    chisel_7 = callPackage ./chisel {
      version = "7.13.0";
      hash = "sha256-L4k6KEUpHSqrp06fthwHfkyTyvpyiNF+iS2GpuQm9z8=";
    };
    chisel = callPackage ./chisel { };

    icsc = callPackage ./icsc { };

    pycircuit_6 = callPackage ./pycircuit {
      version = "6.1.0";
      hash = "sha256-wlulfyf5BLAmWDIDyTdeVzXqZ3gW46Uu2GI2+/8e1Mo=";
    };
    pycircuit = callPackage ./pycircuit { };

    ndf = callPackage ./ndf { };

    aslref = callPackage ./aslref { };

    xls = callPackage ./xls { };

    abc_0 = pinnedOverride basePkgs.abc-verifier "0.70" (githubSource {
      owner = "yosyshq";
      repo = "abc";
      rev = "v0.70";
      hash = "sha256-1w9ozqGqFKPno8vzYBqt0AN8RM5QjqFmluOubEXS1zM=";
    });
    abc = callPackage ./abc {
      abc-verifier = basePkgs.abc-verifier;
    };
    sv2v_0 = basePkgs.haskellPackages.sv2v.overrideAttrs (_old: {
      version = "0.0.13.1";
      src = pkgs.fetchurl {
        url = "mirror://hackage/sv2v-0.0.13.1.tar.gz";
        hash = "sha256-NDSSRynllL+boQe2Ucujki0QxqUeaow/TlMAG2oFu8U=";
      };
    });
    sv2v = callPackage ./sv2v { };

    # firtool releases move faster than nixpkgs' circt: its MLIR comes from an
    # internal circt-llvm derivation that .override cannot reach and that lags
    # behind upstream. Rebuild nixpkgs' own circt-llvm.nix from circt's source
    # instead (the callPackage argument is used exactly once in circt's
    # package.nix, to instantiate circt-llvm), so the MLIR snapshot always
    # matches the pinned firtool tag. fetchSubmodules pulls the llvm/ submodule
    # circt-llvm builds from; firtool >= 1.152 also needs slang 11.
    circt =
      (pinnedOverride
        (basePkgs.circt.override {
          sv-lang_10 = sv-lang_11;
          callPackage = _path: _args: circt-llvm;
        })
        "1.158.0"
        (githubSource {
          owner = "llvm";
          repo = "circt";
          rev = "firtool-1.158.0";
          hash = "sha256-9/RSK2jCV4TvP6vAS4x/YR12NF6z4rPa1BNxTAqiahQ=";
          fetchSubmodules = true;
        })
      ).overrideAttrs
        (old: {
          passthru = old.passthru // {
            # Follow the latest firtool release whatever the major; the auto
            # regex would otherwise lock the "1" in circt as a 1.x series.
            nixchipUpdateFlags = [ "--version-regex=^firtool-([0-9.]+)$" ];
          };
          # Two lit-test classes fail against nixpkgs-provided tools rather than
          # firtool's exact pins: the slang 11.0 release emits loc(unknown)
          # where upstream's slang pin yields real source locations, and the
          # self-contained tblgen checks' custom format needs a newer lit than
          # nixpkgs' LLVM_EXTERNAL_LIT (18.1.8, no maxIndividualTestTime).
          env = old.env // {
            LIT_FILTER_OUT =
              old.env.LIT_FILTER_OUT
              + "|CIRCT :: Conversion/ImportVerilog/(basic|builtins|interface-instance-expansion|proximate-source-locations)\\.sv"
              + "|CIRCT :: Tools/circt-tblgen/self-contained/.*";
          };
        });
    # MLIR/LLVM snapshot for circt, built from its llvm/ submodule. It follows
    # circt's version and src, so a circt bump rebuilds it in lockstep.
    circt-llvm = basePkgs.callPackage (basePkgs.path + "/pkgs/by-name/ci/circt/circt-llvm.nix") {
      circt = circt;
    };
    firrtl_1 = callPackage ./firrtl {
      firrtl = basePkgs.firrtl;
      version = "1.5.3";
      hash = "sha256-7lv3I3TODEWiCWtKwk8Cl9EG8nVwZpz8T0yDjuL2AJg=";
    };
    firrtl = callPackage ./firrtl {
      firrtl = basePkgs.firrtl;
    };

    # ── Waveform & debug ───────────────────────────────────────────────────────
    gtkwave_3 = pinnedOverride basePkgs.gtkwave "3.3.128" (
      pkgs.fetchurl {
        url = "mirror://sourceforge/gtkwave/gtkwave-gtk3-3.3.128.tar.gz";
        hash = "sha256-gX4Zf8GAj4qsNUPCwvloPLATaMkRkrjq5a9YBw7x0fg=";
      }
    );
    gtkwave = callPackage ./gtkwave { };
    surfer_0 = pinnedOverride basePkgs.surfer "0.7.0" (gitlabSource {
      owner = "surfer-project";
      repo = "surfer";
      rev = "v0.7.0";
      hash = "sha256-WO0TWmUaKqUh+Cr75Hrxa2x4V9xZhzHY5PzlIRNUzZA=";
    });
    surfer =
      cargoVendorOverride { cargoHash = "sha256-6dOoPMxOW2+vlTPXQME7OMeXLfWGyi7H3PY77x22TWY="; }
        (
          branchOverride basePkgs.surfer "unstable-2026-11-10" (gitlabSource {
            owner = "surfer-project";
            repo = "surfer";
            rev = "11bb2e3b966a95190cdb75c36899cccb5889d385";
            hash = "sha256-j+Tnzw/Z/vpl6ppVjz1EvTLpiHUGgjIqvPcJAFGEHI0=";
          })
        );
    openocd_0 = pinnedOverride basePkgs.openocd "0.12.0" (
      pkgs.fetchurl {
        url = "mirror://sourceforge/project/openocd/openocd/0.12.0/openocd-0.12.0.tar.bz2";
        hash = "sha256-ryVHiL6Yhh8r2RA/5uYKd07Jaow3R0Tu+Rl/YEMHWvo=";
      }
    );

    # ── Linting, formatting & elaboration ─────────────────────────────────────
    # Release slot built with our bazel package: nixpkgs' verible bakes its
    # dependency fetch into a let binding overrideAttrs cannot reach. The
    # version uses upstream's tag form (v0.0-<n>-g<hash>) so the update bot
    # can follow it; registry and dependency pins are refreshed with it.
    verible_0 =
      (callPackage ./verible {
        version = "0.0-4302-gc6b29d62";
        rev = "v0.0-4302-gc6b29d62";
        hash = "sha256-QedWoBRalRKmrz7H+omqHhEMcqHQ796Wlzsyb0pOLXQ=";
        gitVersion = "v0.0-4302-gc6b29d62";
        registryRev = "6e097e58caf8fdceb8efae0ae21d1ab871a25a82";
        registryHash = "sha256-LwdDEs7uQdKG1L64Pv6u/YNycKPDPGt9PvT+uh+Zlv0=";
        depsHash = "sha256-RXji3oV9ccUfje8+i73w7dox9e4wZH3KADJ+YecFgL4=";
      }).overrideAttrs
        (old: {
          passthru = old.passthru // {
            nixchipUpdateFlags = [ "--version-regex=^v(0\\.0-[0-9]+-g[0-9a-f]+)$" ];
          };
        });
    # Branch-tracking verible built from HEAD with bazel 7 and its own pinned
    # bazel-central-registry snapshot (see pkgs/verible); nixpkgs' verible
    # (verible_0) pins a stale BCR snapshot internally and cannot follow
    # upstream past 083a3689.
    verible = callPackage ./verible { };
    vhdl-ls_0 = callPackage ./vhdl-ls {
      vhdl_ls = basePkgs.vhdl-ls;
      version = "0.87.1";
      hash = "sha256-+7kjRjRtsb038xw0x+yojhWVChvkBz6kTlqSc3rTwXE=";
      # This slot builds a different rev than the branch attr, so it needs its
      # own vendored-crates hash rather than the shared default below it.
      cargoHash = "sha256-NAi/YY6bu/yHHPWfgv5fimS3Ac4PL12T/U1Jknj/Zc8=";
    };
    vhdl-ls = callPackage ./vhdl-ls {
      vhdl_ls = basePkgs.vhdl-ls;
    };
    # Surelog and UHDM release in lockstep (same version numbers); nixpkgs'
    # surelog would otherwise link its own stale uhdm and break on API drift.
    surelog_1 = pinnedOverride (basePkgs.surelog.override { uhdm = uhdm_1; }) "1.87" (githubSource {
      owner = "chipsalliance";
      repo = "surelog";
      rev = "v1.87";
      hash = "sha256-GnaLth2lnH6pCYZYbwsVpREgoGU0SVeDVltqnqBrwkw=";
    });
    # HEAD surelog needs HEAD uhdm (see surelog_1: lockstep releases).
    surelog =
      branchOverride (basePkgs.surelog.override { inherit uhdm; }) "unstable-2026-11-17"
        (githubSource {
          owner = "chipsalliance";
          repo = "surelog";
          rev = "c7ac0a6abecd30da44d221c0c78879791322fc7d";
          hash = "sha256-pkMCSgcR8njHojR6BPPozkdNHhAeBJ4qH9itb+Mtyj4=";
        });
    uhdm_1 = pinnedOverride basePkgs.uhdm "1.87" (githubSource {
      owner = "chipsalliance";
      repo = "UHDM";
      rev = "v1.87";
      hash = "sha256-kCCNe1elZoExc8OAtvRxwKODxCdNuVzjFQkEMntNjqI=";
    });
    uhdm = branchOverride basePkgs.uhdm "unstable-2026-11-17" (githubSource {
      owner = "chipsalliance";
      repo = "UHDM";
      rev = "ffb2734fedcdedef3e7e15f889018b308f6eb6d0";
      hash = "sha256-Zdd3j6J8Gse/AD4zz0BlCDcU1qyE4ByJKkM/3XHy4mc=";
    });

    # ── FPGA back-end ──────────────────────────────────────────────────────────
    bluespec_2024 = pinnedOverride (basePkgs.bluespec.overrideAttrs bluespecFromSubmodules) "2024.07" (githubSource {
      owner = "B-Lang-org";
      repo = "bsc";
      rev = "2024.07";
      hash = "sha256-lRRal/mErZ+sjtbymfFfQHwoh2PL8gHf+ejTEkmcnms=";
      fetchSubmodules = true;
    });
    bluespec_2026 = pinnedOverride (
      basePkgs.bluespec.overrideAttrs (
        old:
        bluespecFromSubmodules old
        // {
          # bsc 2026 builds libstp.so.1 straight from its stub, so nixpkgs'
          # libstp_stub_makefile.patch would install a file that no longer exists.
          patches = [ ];
          # bsc 2026 also links strict-concurrency, missing from nixpkgs' ghc env.
          nativeBuildInputs = map (
            dep:
            if lib.hasInfix "-with-packages" (dep.name or "") then
              basePkgs.ghc.withPackages (g: [
                g.old-time
                g.regex-compat
                g.syb
                g.split
                g.strict-concurrency
              ])
            else
              dep
          ) old.nativeBuildInputs;
        }
      )
    ) "2026.07.1" (githubSource {
      owner = "B-Lang-org";
      repo = "bsc";
      rev = "2026.07.1";
      hash = "sha256-P5AdiFKPpvOpS3lKhX7OMBNDzemE//IwFl86MKXomP8=";
      fetchSubmodules = true;
    });
    # Upstream's last release (0.9.2) predates nixpkgs' snapshot, so this slot
    # tracks the branch rather than a release series.
    migen = branchOverride basePkgs.python3Packages.migen "unstable-2025-10-03" (githubSource {
      owner = "m-labs";
      repo = "migen";
      rev = "147f003fb7076ac4c7cf76a9a5ce152dc10e0ca6";
      hash = "sha256-gRAvl5cUvrjq4t7htXsDBt4F8MEbHXFZoS0jbhrEs1I=";
    });
    # 3rdparty/googletest is a submodule; without fetchSubmodules its dir is
    # empty and CMake aborts (BUILD_TESTS is on in the nixpkgs base).
    nextpnr_0 = pinnedOverride nextpnrBase "0.11.1" (taggedGithubSource {
      owner = "YosysHQ";
      repo = "nextpnr";
      rev = "nextpnr-0.11.1";
      hash = "sha256-QUE19KWr26n5q8C7Byjg+pLdsKf50Fr/FqU9srlvYtU=";
      fetchSubmodules = true;
    });
    # 3rdparty/googletest and tests/gui are submodules; without fetchSubmodules
    # their directories are empty and CMake aborts on the missing subdirectories.
    nextpnr = branchOverride nextpnrHeadBase "unstable-2026-11-10" (taggedGithubSource {
      owner = "YosysHQ";
      repo = "nextpnr";
      rev = "445e2a65b46693bb751e9d901d14180ba90db0c8";
      hash = "sha256-AmHujX79S9TD9aPA3NmeRYL9CNmPUA5e5MN2RzOn+9k=";
      fetchSubmodules = true;
    });
    icestorm = branchOverride basePkgs.icestorm "unstable-2026-11-10" (githubSource {
      owner = "YosysHQ";
      repo = "icestorm";
      rev = "00da9c3e6ceff056248e3451dd6fd3210d6ceec9";
      hash = "sha256-sXfNf03s1fRQtGVFE5ArZBKjTkBqDLdM9L+SK/ivzSM=";
    });
    # Branch-tracking; tagged releases live in trellis_1.
    trellis = branchOverride (basePkgs.trellis.overrideAttrs trellisFromSubmodules) "unstable-2026-11-16" (githubSource {
      owner = "YosysHQ";
      repo = "prjtrellis";
      rev = "2d12005ab9703ff60603d7ae91dca254939e671f";
      hash = "sha256-bWTyT9qUu0Vs7e+qoPfCSSm2//6rHG4wgKKsjbULRps=";
      fetchSubmodules = true;
    });
    trellis_1 = pinnedOverride (basePkgs.trellis.overrideAttrs trellisFromSubmodules) "1.4" (githubSource {
      owner = "YosysHQ";
      repo = "prjtrellis";
      rev = "1.4";
      hash = "sha256-rFK4rs98tDTZROsLz6WKg7wHn7PDcrUHNsxWmV3TajA=";
      fetchSubmodules = true;
    });
    openfpgaloader_1 = pinnedOverride basePkgs.openfpgaloader "1.2.0" (githubSource {
      owner = "trabucayre";
      repo = "openFPGALoader";
      rev = "v1.2.0";
      hash = "sha256-xz5acJJLRfWsJmcPL3R2PWwZgnBRUHibkGf1sHVUPn4=";
    });
    openfpgaloader = branchOverride basePkgs.openfpgaloader "unstable-2026-11-18" (githubSource {
      owner = "trabucayre";
      repo = "openFPGALoader";
      rev = "ab8c9477939c155e07c1264819d6125715103e3f";
      hash = "sha256-AmG48Rr3JrDfKRPw610gL72Jj7BGwXI90ZS+PoQ7MpU=";
    });
    vtr_7 = callPackage ./vtr7 {
      version = "7";
      hash = "sha256-/tb/ZA3k30oijfLHOLuE9OAEVRqj3bkb2Yx6aXnZ3uA=";
    };
    vtr_8 = callPackage ./vtr {
      version = "8.0.0";
      rev = "v8.0.0";
      fetchSubmodules = false;
      hash = "sha256-BDZcfG38b9jwqWDv2iOSKDAl+kbKobGXnZkYA9AZsJM=";
    };
    vtr_9 = callPackage ./vtr {
      version = "9.0.0";
      rev = "v9.0.0";
      hash = "sha256-g5pDGy6A0e1gHFU64G7NcTAGiUj8vfyhJkQ3++4Y2yw=";
    };
    vtr = callPackage ./vtr { };
    fusesoc_2 = callPackage ./fusesoc {
      fusesoc = basePkgs.fusesoc;
      pydantic = basePkgs.python3Packages.pydantic;
      version = "2.4.6";
      hash = "sha256-d4ro802pkpZqm5MYg3Yplu8IhKhVEqR5MfvrCsLcdYU=";
    };
    fusesoc = callPackage ./fusesoc {
      fusesoc = basePkgs.fusesoc;
      pydantic = basePkgs.python3Packages.pydantic;
      inherit edalize;
    };

    # ── Physical design ────────────────────────────────────────────────────────
    openroad_26 = callPackage ./openroad/cmake.nix {
      openroad = openroadBase;
      version = "26Q4";
      rev = "26Q4";
      hash = "sha256-6DTXTlgRysxhphUx3TyZvC5p8rZ/XkHxJriLHLD8V20=";
    };
    openroad = callPackage ./openroad { };
    openroad-flow-scripts_26 = callPackage ./openroad-flow-scripts {
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
    klayout_0 = callPackage ./klayout {
      klayout = basePkgs.klayout;
      version = "0.30.8";
      hash = "sha256-RjMH6hrc0jyCLgG1D6cztBp5Fb3W5HgTxVTfI2bxgCs=";
    };
    klayout = callPackage ./klayout {
      klayout = basePkgs.klayout;
    };
    magic-vlsi_8 = callPackage ./magic-vlsi {
      magic-vlsi = basePkgs.magic-vlsi;
      version = "8.3.629";
      hash = "sha256-K/w2El2jkXN8qIa0kWvN8rCKWzjd8DcM3O6hb5UVQnw=";
    };
    magic-vlsi = callPackage ./magic-vlsi { magic-vlsi = basePkgs.magic-vlsi; };
    netgen-vlsi_1 = pinnedOverride basePkgs.netgen-vlsi "1.5.321" (githubSource {
      owner = "RTimothyEdwards";
      repo = "netgen";
      rev = "refs/tags/1.5.321";
      hash = "sha256-jq7JvChnNSeZf7OrV9EIiOPv5nDqs6r8L9TY6k4vGXc=";
    });

    # ── Analog & mixed-signal ─────────────────────────────────────────────────
    ngspice_45 =
      (pinnedOverride basePkgs.ngspice "45.2" (
        pkgs.fetchurl {
          url = "mirror://sourceforge/ngspice/ngspice-45.2.tar.gz";
          hash = "sha256-uoNF9MN3RxTBDzPX2oUNNhzsfRSzopXQ3J/Zb3QjgS0=";
        }
      )).overrideAttrs
        {
          # The 45.2 tarball ships configure.ac with a newer mtime than the
          # generated aclocal.m4/configure/Makefile.in, so automake's maintainer
          # rebuild rules fire during make and call aclocal-1.16, which nothing
          # in the build inputs provides. Restamp the generated files instead of
          # pulling in an autotools chain that would have to match 1.16 exactly.
          postPatch = ''
            find . \( -name aclocal.m4 -o -name configure -o -name Makefile.in -o -name config.h.in \) \
              -exec touch {} +
          '';
        };
    xyce_7 = basePkgs.xyce.overrideAttrs (_old: {
      version = "7.10.0";
    });
    qucs-s_25 = pinnedOverride basePkgs.qucs-s "25.2.0" (githubSource {
      owner = "ra3xdh";
      repo = "qucs_s";
      rev = "refs/tags/25.2.0";
      hash = "sha256-U5XLjWKOXNjgYtlccNsPT1nUnEGi3NhkJ36jan2OSAw=";
    });
    qucs-s_26 = pinnedOverride (basePkgs.qucs-s.overrideAttrs qucsSFixes) "26.1.1" (githubSource {
      owner = "ra3xdh";
      repo = "qucs_s";
      rev = "refs/tags/26.1.1";
      hash = "sha256-f+8EdTZLQcbP+WEXUlVg/vIj+jp1FQ7E0QT0gsXfgTw=";
      fetchSubmodules = true;
    });
    qucs-s = branchOverride (basePkgs.qucs-s.overrideAttrs qucsSFixes) "unstable-2026-11-17" (githubSource {
      owner = "ra3xdh";
      repo = "qucs_s";
      rev = "941b4b2a2774d5db581dfb3538c0b4f83165dcfc";
      hash = "sha256-RV2sYlqUuwKBaeVD0H8s5hAQ2Tpe9MXYuaFHUUfz9uQ=";
      fetchSubmodules = true;
    });
    xschem_3 = callPackage ./xschem {
      xschem = basePkgs.xschem;
      version = "3.4.7";
      hash = "sha256-ye97VJQ+2F2UbFLmGrZ8xSK9xFeF+Yies6fJKurPOD0=";
    };
    xschem = callPackage ./xschem {
      xschem = basePkgs.xschem;
    };

    # ── Formal verification ────────────────────────────────────────────────────
    sby_0 = pinnedOverride basePkgs.sby "0.70" (githubSource {
      owner = "YosysHQ";
      repo = "sby";
      rev = "v0.70";
      hash = "sha256-vZpp2uWferqWu8IRA8QnHCQXhB4ciNaEm9S29LJDLFg=";
    });
    sby = branchOverride basePkgs.sby "unstable-2026-11-17" (githubSource {
      owner = "YosysHQ";
      repo = "sby";
      rev = "b21f778333efc1e7c33fe22b56d43f87e4f759d4";
      hash = "sha256-m1Cq8iky37EhNYiZkrtyhum7i3LwP+A9uu6CNwR5umc=";
    });
    eqy_0 = callPackage ./eqy {
      yosys = yosys_0;
      version = "0.66";
      hash = "sha256-RtUSkPal+jeSdGkof4R3fg1qIxiThc8rPQZzECpHTtM=";
    };
    eqy = callPackage ./eqy { };
    mcy_0 = pinnedOverride basePkgs.mcy "0.71" (githubSource {
      owner = "YosysHQ";
      repo = "mcy";
      rev = "v0.71";
      hash = "sha256-50IFGHuqL9ayghtobtryo/HTvRmMEmI28YxHnyFRIrY=";
    });

    yices_2 = pinnedOverride basePkgs.yices "2.7.0" (githubSource {
      owner = "SRI-CSL";
      repo = "yices2";
      rev = "yices-2.7.0";
      hash = "sha256-siyepgxqKWRyO4+SB95lmhJ98iDubk0R0ErEJdSsM8o=";
    });
    boolector_3 = pinnedOverride basePkgs.boolector "3.2.4" (githubSource {
      owner = "boolector";
      repo = "boolector";
      rev = "refs/tags/3.2.4";
      hash = "sha256-CKhaPaWUB6Fz0LfnCl81LVmTebCWzTvZLKeC0KH3by4=";
    });
    bitwuzla_0 = pinnedOverride basePkgs.bitwuzla "0.9.1" (githubSource {
      owner = "bitwuzla";
      repo = "bitwuzla";
      rev = "refs/tags/0.9.1";
      hash = "sha256-3uStLdDFhXVgqzremUPRbxPUcl0IqVg5MRLltgm8rCA=";
    });
    cadical_3 = pinnedOverride basePkgs.cadical "3.0.1" (githubSource {
      owner = "arminbiere";
      repo = "cadical";
      rev = "rel-3.0.1";
      hash = "sha256-oHebG9VBtEnxmBpfP6A/f/UNIx2AXbLPs0NHPoNlZfY=";
    });
    # cryptominisat pulls CaDiCaL and CaDiBack in with FetchContent at configure time,
    # which no sandbox can do. Both are meelgroup forks declared as unpinned
    # branches, so the revisions come from upstream's own flake.lock -- the one
    # combination cryptominisat is released against.
    cryptominisat_5 =
      (pinnedOverride basePkgs.cryptominisat "5.18.0" (githubSource {
        owner = "msoos";
        repo = "cryptominisat";
        rev = "release/v5.18.0";
        hash = "sha256-E8FaUz4FEnB1+qfFRzatZgQ9BEosKWncYxUK40wmKXs=";
      })).overrideAttrs
        (old: {
          # Upstream renamed src/picosat -> src/mpicosat and already uses plain
          # <unistd.h>, so the musl sys/unistd.h compat patch no longer applies.
          postPatch = "";
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
          buildInputs = (old.buildInputs or [ ]) ++ [
            pkgs.gmp
            pkgs.zlib
          ];
          cmakeFlags = (old.cmakeFlags or [ ]) ++ [
            (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_CADICAL"
              (githubSource {
                owner = "meelgroup";
                repo = "cadical";
                rev = "818c9562f114b315a9246ced943b66b60b38e8fb";
                hash = "sha256-Ff8iH6CqMPdcqOSN6gjVqbJ1qKuHlwqrl/vW/nCtGPU=";
              }).outPath
            )
            (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_CADIBACK"
              (githubSource {
                owner = "meelgroup";
                repo = "cadiback";
                rev = "47a6d821085ef8cb033241659824beafeb798cff";
                hash = "sha256-UIJhXYwTq3orU9hhR4KbMd2Jb7dp7n3ZX141xOBzolU=";
              }).outPath
            )
          ];
        });
    z3_4 = pinnedOverride basePkgs.z3 "4.16.0" (githubSource {
      owner = "Z3Prover";
      repo = "z3";
      rev = "z3-4.16.0";
      hash = "sha256-DnhX3kxggnFmyYwXEPBsBA1rh4oor1oIJR5TMJk/jvc=";
    });
    z3_5 = pinnedOverride (basePkgs.z3.overrideAttrs z3Fixes) "5.4.1" (githubSource {
      owner = "Z3Prover";
      repo = "z3";
      rev = "z3-5.4.1";
      hash = "sha256-wac7ZB8HOFxcw5fdOfWu8wiMHFQ/z+dLMJE4Q32xbsI=";
    });
    z3 = branchOverride (basePkgs.z3.overrideAttrs z3Fixes) "unstable-2026-11-17" (githubSource {
      owner = "Z3Prover";
      repo = "z3";
      rev = "5e70128898c321efaade5afeb5e2b9f899769175";
      hash = "sha256-T16l/v2fxHR8F/XE/4s33qAfEQd34D3Gr2DlxXBEQgo=";
    });
    cvc5_1 = pinnedOverride basePkgs.cvc5 "1.4.2" (githubSource {
      owner = "cvc5";
      repo = "cvc5";
      rev = "cvc5-1.4.2";
      hash = "sha256-GhqYYTbn0mh/EjoXy9ovKWRtFXYoeuHGp0KuYvfwH7w=";
    });
    # cvc5 now refuses a system SymFPU without the patches it carries in
    # cmake/deps-utils; SymFPU is header-only, so apply them from cvc5's own src.
    cvc5 = branchOverride (basePkgs.cvc5.overrideAttrs (
      finalAttrs: old: {
        buildInputs = map (
          dep:
          if (dep.pname or "") == "symfpu" then
            dep.overrideAttrs (o: {
              patches =
                (o.patches or [ ])
                ++ map (n: "${finalAttrs.src}/cmake/deps-utils/symfpu-${n}.patch") [
                  "0001-fix-conversions-for-experimental-formats"
                  "0002-fix-unpacked-exponent-width-for-small-formats"
                  "0003-define-cvc5-patch-level"
                ];
            })
          else
            dep
        ) old.buildInputs;
      }
    )) "unstable-2026-11-10" (githubSource {
      owner = "cvc5";
      repo = "cvc5";
      rev = "00147fb17d7ed9046f3b09deee0b4951c0243b3f";
      hash = "sha256-+Xzg2xpXCc6uneywOqlLKktZnzVeACAP2KjHnIP/v50=";
    });

    aiger_1 = callPackage ./aiger {
      aiger = basePkgs.aiger;
      version = "1.9.20";
      hash = "sha256-ggkxITuD8phq3VF6tGc/JWQGBhTfPxBdnRobKswYVa4=";
    };
    aiger = callPackage ./aiger {
      aiger = basePkgs.aiger;
    };
    btor2tools_1 = pinnedOverride basePkgs.btor2tools "1.0.4" (githubSource {
      owner = "boolector";
      repo = "btor2tools";
      rev = "1.0.4";
      hash = "sha256-GTzZKnMhSb5Fbf+ZxiHfvydXJHSI/nsl+YCXKxJIkRY=";
    });

    # ── Accelerator DSE (Timeloop / Accelergy) ─────────────────────────────────
    # timeloop, timeloopfe, accelergy and its plug-ins have no releases and
    # track upstream HEAD; barvinok is a pinned release.
    barvinok = callPackage ./barvinok { };
    timeloop = callPackage ./timeloop { };
    accelergy = callPackage ./accelergy {
      inherit (basePkgs.python3Packages)
        buildPythonPackage
        deepdiff
        jinja2
        pyfiglet
        pyyaml
        ruamel-yaml
        ;
    };
    timeloopfe = callPackage ./timeloopfe {
      inherit (basePkgs.python3Packages)
        buildPythonPackage
        ruamel-yaml
        psutil
        joblib
        ;
    };
    accelergy-library-plug-in = callPackage ./accelergy-library-plug-in {
      inherit (basePkgs.python3Packages) buildPythonPackage pyyaml;
    };
    accelergy-cacti-plug-in = callPackage ./accelergy-cacti-plug-in {
      inherit (basePkgs.python3Packages) buildPythonPackage pyyaml;
    };

    # ── Microarchitecture modeling ─────────────────────────────────────────────
    # NoC simulators: booksim2 is the standard reference simulator; noxim is
    # SystemC-based and must build against the same C++ standard as the
    # systemc_2 (2.3.x, C++14) library it links.
    booksim2 = callPackage ./booksim2 { };
    noxim = callPackage ./noxim { systemc = systemc_2; };
    # 3D-ICE: attr is "threed-ice" (matching its libthreed-ice library), not
    # "3d-ice" — a leading digit would make mkNixchipVarsHook emit an invalid
    # `3D_ICE_HOME` shell variable and break every dev shell hook.
    threed-ice = callPackage ./3d-ice { };
    champsim = callPackage ./champsim { };
    # Pythia: CMU-SAFARI's ChampSim fork with the RL prefetcher framework; the
    # full source tree is shipped under share/pythia so downstream projects can
    # copy it and rebuild with their own prefetchers.
    pythia = callPackage ./pythia { };
    # Trailing digits in these upstream names are part of the name, not a
    # version slot; per convention they take a trailing underscore (a future
    # major pin would be e.g. gem5_25 / ramulator2_3).
    ramulator2 = callPackage ./ramulator2 { };
    gem5 = callPackage ./gem5 { };
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
    cacti_6 = callPackage ./cacti {
      version = "6.5.0";
      rev = "v6.5.0";
      hash = "sha256-lYhaDQgQngoJs5GST+dTNPitVSmKhhivFtnzJH2XpdA=";
    };
    # CACTI 7 has no release tag; upstream master is the 7.x line. Frozen at
    # that commit (not updated) as a fixed 7.x reference; `cacti` tracks HEAD.
    cacti_7 =
      (callPackage ./cacti {
        version = "7.0-unstable-2026-06-20";
        rev = "1ffd8dfb10303d306ecd8d215320aea07651e878";
        hash = "sha256-lrbrwKlaVvwEUDZA/n8I/zYNX3T8ltiBTYL94Ce5UQU=";
      }).overrideAttrs
        (old: {
          passthru = old.passthru // {
            nixchipUpdate = false;
          };
        });
    cacti = callPackage ./cacti { };

    dramsim3_1 = callPackage ./dramsim3 {
      version = "1.0.0";
      hash = "sha256-uErpWJEn6C9oKR6Bv1NOAC3ij3ne3A6BPtjtX7D8ZwE=";
    };
    dramsim3 = callPackage ./dramsim3 { };
    mcpat_1 = callPackage ./mcpat {
      version = "1.3.0";
      hash = "sha256-sr7H2vBOTyI59d3itVNqRVy1fR/83ZrTGl5s4I+g0Tw=";
    };
    mcpat = callPackage ./mcpat { };
    hotspot_7 = callPackage ./hotspot {
      version = "7.0";
      hash = "sha256-AM8kTu0Rxpee3easDBKtu6+ld6lmpNVNO1z2jOQmhls=";
    };
    hotspot = callPackage ./hotspot { };

    # ── SoC frameworks ────────────────────────────────────────────────────────
    chipyard_1 = callPackage ./chipyard {
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
        uv-build
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
    zigzag-dse = callPackage ./zigzag-dse {
      inherit (basePkgs.python3Packages)
        buildPythonPackage
        numpy
        networkx
        sympy
        matplotlib
        tqdm
        pyyaml
        cerberus
        seaborn
        typeguard
        protobuf
        typing-extensions
        ml-dtypes
        dill
        ;
    };
    stream-dse = callPackage ./stream-dse {
      python = basePkgs.python3;
      inherit (basePkgs.python3Packages)
        buildPythonPackage
        cerberus
        pydantic
        pydot
        immutabledict
        ordered-set
        typing-extensions
        absl-py
        numpy
        pandas
        protobuf
        ;
    };
    chia = callPackage ./chia {
      inherit (basePkgs.python3Packages)
        buildPythonPackage
        setuptools
        wheel
        google-genai
        ray
        mcp
        pydantic
        fastapi
        pyyaml
        pytest
        graphviz
        boto3
        google-cloud-compute
        requests
        ;
    };
    cocotb_2 = callPackage ./cocotb {
      # cocotb 2.0.x caps at python 3.13 (setup.py max_python3_minor_version),
      # so the release slot stays on the 3.13 package set now that the default
      # python3 is 3.14.
      cocotb = basePkgs.python313Packages.cocotb;
      version = "2.0.1";
      hash = "sha256-LXQNqFlvP+WBaDGWPs5+BXBtW2dhDu+v+7lR/AMG21M=";
    };
    cocotb = callPackage ./cocotb {
      cocotb = basePkgs.python3Packages.cocotb;
    };
    edalize_0 = callPackage ./edalize {
      edalize = basePkgs.python3Packages.edalize;
      version = "0.6.1";
      hash = "sha256-5c3Szq0tXQdlyzFTFCla44qB/O6RK8vezVOaFOv8sw4=";
    };
    edalize = callPackage ./edalize {
      edalize = basePkgs.python3Packages.edalize;
    };
    amaranth_0 = callPackage ./amaranth {
      amaranth = basePkgs.python3Packages.amaranth;
      version = "0.5.8";
      hash = "sha256-hqMgyQJRz1/5C9KB3nAI2RKPZXZUl3zhfZbk9M1hTxs=";
    };
    amaranth = callPackage ./amaranth {
      amaranth = basePkgs.python3Packages.amaranth;
    };

    # ── AI coding agents ──────────────────────────────────────────────────────
    # Upstream's prebuilt release binaries, not nixpkgs' (which lag by months):
    # one hash per platform in each sources.json, bumped by
    # scripts/update-ai-agents.sh rather than nix-update. claude-code is
    # unfree, so like espresso it is not an attr here and only joins ai-tools
    # when allowed (allowUnfree or allowUnfreePredicate; the flake's own
    # package set allows it).
    codex = callPackage ./codex { };
    opencode = callPackage ./opencode { };

    # ── Tool bundles ──────────────────────────────────────────────────────────
    simulation-tools = pkgs.symlinkJoin {
      name = "nixchip-simulation-tools";
      paths = [
        verilator
        sv-lang
        chisel
        systemc
        ghdl
        nvc_1
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
        yices_2
        boolector_3
        bitwuzla_0
        cadical_3
        cryptominisat_5
        cvc5
        z3
        abc
        aiger
        btor2tools_1
        mcy_0
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
        openocd_0
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
        circt
        firrtl
        klayout
        magic-vlsi
        netgen-vlsi_1
      ]
      ++ optionalUnfreePackage "espresso";
    };

    analog-tools = pkgs.symlinkJoin {
      name = "nixchip-analog-tools";
      paths = [
        ngspice_45
        xyce_7
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

    ai-tools = pkgs.symlinkJoin {
      name = "nixchip-ai-tools";
      paths = [
        codex
        opencode
      ]
      ++ map (claude-code: callPackage ./claude-code { inherit claude-code; }) (
        optionalUnfreePackage "claude-code"
      );
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
# Top-level aliases for convenience. z3 and cvc5 are deliberately NOT exported
# at the top level: they are core solver libraries consumed by many nixpkgs
# packages (and re-resolved by basePkgs.*.override calls), so shadowing them
# with nixchip's HEAD builds would rebuild or alter unrelated packages.
# They stay reachable as pkgs.nixchip.z3 / pkgs.nixchip.cvc5.
// (builtins.removeAttrs nixchipPackages [
  "z3"
  "cvc5"
])
