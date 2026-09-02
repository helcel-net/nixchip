# nixchip

`nixchip` is a Nix flake for open hardware development. Hardware packages live
under `pkgs/`; general development tools such as Python, Node.js, Git, Make, and
shell linters come directly from nixpkgs in the dev shells.

## Quick start

```sh
nix develop github:helcel-net/nixchip              # full hardware toolbox
nix develop github:helcel-net/nixchip#simulation   # simulators + waveform viewers
nix develop github:helcel-net/nixchip#fpga         # synthesis + place-and-route
nix develop github:helcel-net/nixchip#asic         # physical design + analog + formal
nix develop github:helcel-net/nixchip#versions     # side-by-side verilator_3/4/5, systemc_2/3, etc.
```

Every shell exports `${PKGNAME}_HOME`, `${PKGNAME}_BIN`, `${PKGNAME}_LIB`, and
`${PKGNAME}_INCLUDE` for every individual package in the collection, regardless
of which packages are in `packages =`. See [Environment variables](#environment-variables).

## Use as a flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixchip.url = "github:helcel-net/nixchip";
  };

  outputs =
    { nixpkgs, nixchip, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nixchip.overlays.default ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          pkgs.nixchip.hardware-tools
          pkgs.nixchip.verilator_4
        ];
        shellHook = nixchip.lib.mkNixchipVarsHook pkgs.nixchip;
      };
    };
}
```

The overlay exports packages under both `pkgs.nixchip.*` and top-level package
names such as `pkgs.verilator_4`.

### Binary caches

CI pushes every build to the `nixchip0` Cachix cache, declared in this flake's
`nixConfig` — running any nix command with `--accept-flake-config` (or
`accept-flake-config = true` in `nix.conf`) substitutes it automatically.

To actually get cache hits, consume nixchip's packages built against
**nixchip's own nixpkgs pin**. Overriding it rewrites every derivation hash and
forces full source rebuilds:

```nix
# Cache-friendly: share nixchip's pin.
inputs.nixchip.url = "github:helcel-net/nixchip";
inputs.nixpkgs.follows = "nixchip/nixpkgs";

# Cache-hostile: every nixchip package rebuilds from source.
# inputs.nixchip.inputs.nixpkgs.follows = "nixpkgs";
```

If you must keep your own nixpkgs pin, use a second, un-overridden nixchip
input for the heavy EDA tools and your own pin for everything else.

For non-hardware tooling, use nixpkgs directly:

```nix
pkgs.mkShellNoCC {
  packages = [
    pkgs.nixchip.hardware-tools
    pkgs.python3
    pkgs.nodejs
    pkgs.shellcheck
  ];
}
```

## Use from `nix-shell`

Create a `shell.nix`:

```nix
let
  nixchip = builtins.getFlake "github:helcel-net/nixchip";
  system = builtins.currentSystem;
  pkgs = nixchip.legacyPackages.${system};
in
pkgs.mkShellNoCC {
  packages = [
    pkgs.nixchip.hardware-tools
  ];
  shellHook = nixchip.lib.mkNixchipVarsHook pkgs.nixchip;
}
```

Then run:

```sh
nix-shell --experimental-features 'nix-command flakes'
```

## Environment variables

Every dev shell (including downstream shells that call `mkNixchipVarsHook`)
exports four variables per package:

| Variable | Value |
|---|---|
| `PKGNAME_HOME` | Nix store path (package root) |
| `PKGNAME_BIN` | `$PKGNAME_HOME/bin` |
| `PKGNAME_LIB` | `$PKGNAME_HOME/lib` |
| `PKGNAME_INCLUDE` | `$PKGNAME_HOME/include` |

Package name to env prefix: hyphens become underscores, all uppercase.

Examples:

```
verilator_4       → VERILATOR_4_HOME / VERILATOR_4_BIN / VERILATOR_4_LIB / VERILATOR_4_INCLUDE
systemc_2         → SYSTEMC_2_HOME / SYSTEMC_2_BIN / SYSTEMC_2_LIB / SYSTEMC_2_INCLUDE
sv-lang_9         → SV_LANG_9_HOME / SV_LANG_9_BIN / ...
yosys-full_0      → YOSYS_FULL_0_HOME / YOSYS_FULL_0_BIN / ...
gem5              → GEM5_HOME / ...
qucs-s_25         → QUCS_S_25_HOME / ...
```

Tool-group bundles (`*-tools`) and Python-only packages (`cocotb`, `edalize`)
are excluded from the export because they are meant to be used differently.

### `mkNixchipVarsHook` for downstream flakes

`nixchip.lib.mkNixchipVarsHook` takes a `pkgs.nixchip` attribute set and
returns a shell hook string. Wire it in as shown in the flake input example
above. The hook is evaluated at evaluation time — no runtime lookups occur.

## Packages

### Custom derivations (source-pinned)

| Attribute | Version | Description |
|---|---|---|
| `verilator_3` | 3.926 | Verilator 3.x — latest upstream 3.x tag |
| `verilator_4` | 4.228 | Verilator 4.x — latest upstream 4.x tag |
| `systemc_2` | 2.3.4 | SystemC 2.x (accellera-official/systemc, C++14) |
| `systemc_3` | 3.0.2 | SystemC 3.x (accellera-official/systemc, C++17) |
| `vtr_9` | 9.0.0 | Verilog-to-Routing — VPR place-and-route |
| `eqy_0` | 0.66 | YosysHQ equivalence checker |
| `yosys-slang0` | — | povik/yosys-slang Yosys plugin |
| `chisel_7` | 7.x | Chisel 7 with `chisel-init`, `chisel-scala-cli`, `chisel-mill`, `chisel-sbt` |
| `chipyard_1` | 1.x | Chipyard SoC framework with `chipyard-init` |
| `openroad-flow-scripts_26` | 26Q2 | OpenROAD Flow Scripts with `openroad-flow-scripts-init` |
| `openroad-flow-scripts-wrapper`, `orfs` | — | `orfs` wrapper for running OpenROAD Flow Scripts with tool PATH setup |
| `hotspot_7` | 7 | HotSpot thermal modeling (uvahotspot/HotSpot) |
| `dramsim3_1` | 1 | DRAMsim3 memory simulator (umd-memsys/DRAMsim3) |
| `mcpat_1` | 1 | McPAT power/area/timing model (HewlettPackard/mcpat) |
| `cacti_6` | 6.5.0 | CACTI 6 cache/memory model |
| `cacti_7` | 7 pinned | CACTI 7 (HewlettPackard/cacti commit `1ffd8df`) |
| `barvinok` | 0.41.6 | Parametric-polytope point counting (Timeloop v4 link dependency) |
| `timeloop` | 4.0 pinned | Timeloop v4 accelerator mapper/model (NVlabs/timeloop) |
| `accelergy` | 0.4 pinned | Accelergy energy-estimation framework |
| `timeloopfe` | 0.4 pinned | Timeloop v4 Python front-end |
| `accelergy-library-plug-in` | pinned | Accelergy `Library` estimator plug-in |
| `accelergy-cacti-plug-in` | pinned | Accelergy CACTI estimators, bundling nixchip's `cacti` |
| `zigzag-dse` | 3.8.5 | ZigZag accelerator DSE (KU Leuven MICAS), with PyPI-wheel onnx |
| `stream-dse` | 1.13.11 | Stream multi-core DSE, with ortools/xdsl wheel satellites |
| `chia` | 0.1.0 | CHIA agentic hardware-design loops (ucb-bar/chia, pinned commit) |
| `booksim2` | pinned | Booksim2 cycle-accurate NoC simulator |
| `noxim` | pinned | Noxim SystemC NoC simulator (built against `systemc_2`) |
| `threed-ice` | pinned | 3D-ICE thermal simulator for 3D ICs (EPFL ESL) |
| `champsim` | pinned | ChampSim trace-based CPU cache/memory simulator |
| `pythia` | pinned | Pythia RL prefetcher framework on ChampSim (CMU-SAFARI); full source tree in `share/pythia` for custom prefetchers |
| `ramulator2` | 2.0a | Ramulator 2 cycle-accurate DRAM simulator (CMU-SAFARI) |
| `gem5` | 25.1.0.1 | gem5 architectural simulator, RISC-V build (gem5/gem5 tag v25.1.0.1) |

### Forwarded from nixpkgs (version-tracked)

| Attribute | Alias of | Description |
|---|---|---|
| `verilator_5` | `basePkgs.verilator` | Verilator from nixpkgs |
| `yosys_0`, `yosys-full_0` | `basePkgs.yosys` | Yosys (full = with GHDL plugin if available) |
| `sv-lang_9` | `basePkgs.sv-lang_9` | LLVM/slang SystemVerilog compiler 9.x |
| `sv-lang_10` | `basePkgs.sv-lang_10` | slang 10.x |
| `sv-lang_11` | `basePkgs.sv-lang` | slang 11.x (latest) |
| `abc_0` | `basePkgs.abc-verifier` | Fixed ABC logic synthesis and verification release |
| `sv2v_0` | `basePkgs.haskellPackages.sv2v` | SystemVerilog-to-Verilog converter |
| `ghdl_6` | 6.0.0 | Fixed GHDL 6 release |
| `nvc_1` | `basePkgs.nvc` | NVC VHDL compiler/simulator |
| `vhdl-ls_0` | `basePkgs.vhdl-ls` | VHDL language server |
| `spike_1` | `basePkgs.spike` | RISC-V ISA simulator |
| `surfer_0` | `basePkgs.surfer` | Surfer waveform viewer |
| `verible_0` | `basePkgs.verible` | SystemVerilog linter and formatter |
| `surelog_1` | `basePkgs.surelog` | SystemVerilog preprocessor and elaborator |
| `uhdm_1` | `basePkgs.uhdm` | Universal Hardware Data Model |
| `openroad_26` | `basePkgs.openroad` | OpenROAD physical design suite |
| `circt` | `basePkgs.circt` | CIRCT / MLIR circuit IR tools |
| `firrtl_1` | `basePkgs.firrtl` | Fixed FIRRTL 1.x compiler release |
| `klayout_0` | `basePkgs.klayout` | KLayout GDSII viewer and editor |
| `magic-vlsi_8` | `basePkgs.magic-vlsi` | Magic VLSI layout tool |
| `netgen-vlsi_1` | `basePkgs.netgen-vlsi` | Netgen LVS tool |
| `ngspice_45` | `basePkgs.ngspice` | ngspice circuit simulator |
| `xyce_7` | `basePkgs.xyce` | Xyce parallel circuit simulator |
| `qucs-s_25` | `basePkgs.qucs-s` | Qucs-S schematic-driven simulator |
| `xschem_3` | `basePkgs.xschem` | Xschem schematic editor |
| `fusesoc_2` | `basePkgs.fusesoc` | Fixed FuseSoC 2.x release |
| `cocotb_2` | `basePkgs.python3Packages.cocotb` | Python co-simulation framework |
| `edalize_0` | `basePkgs.python3Packages.edalize` | EDA tool abstraction library |
| `sby_0` | `basePkgs.sby` | SymbiYosys formal verification front-end |
| `sail-riscv_0` | `basePkgs.sail-riscv` | Sail RISC-V golden ISA model |
| `bluespec_2024` | `basePkgs.bluespec` | Bluespec Compiler (bsc) |
| `migen_0` | `basePkgs.python3Packages.migen` | Migen Python HDL |
| `yices_2` | `basePkgs.yices` | Yices 2 SMT solver |
| `boolector_3` | `basePkgs.boolector` | Boolector SMT solver |
| `bitwuzla_0` | `basePkgs.bitwuzla` | Bitwuzla SMT solver |
| `cadical_3` | `basePkgs.cadical` | CaDiCaL SAT solver |
| `cryptominisat_5` | `basePkgs.cryptominisat` | CryptoMiniSat SAT solver |
| `aiger_1` | `basePkgs.aiger` | Fixed AIGER 1.x AIG format tools release |
| `btor2tools_0` | `basePkgs.btor2tools` | BTOR2 word-level model checking tools |
| `mcy_0` | `basePkgs.mcy` | YosysHQ mutation cover for formal tests |

Package naming convention: unsuffixed custom package attributes track upstream branch HEAD and use `unstable-YYYY-MM-DD` versions. Numbered attributes are fixed release slots for side-by-side tool versions.

Branch-tracking defaults: `abc`, `aiger`, `amaranth`, `cacti`, `chipyard`, `chisel`, `cocotb`, `edalize`, `eqy`, `firrtl`, `fusesoc`, `ghdl`, `gtkwave`, `hotspot`, `klayout`, `openroad`, `openroad-flow-scripts`, `spike`, `sv-lang`, `slang`, `sv2v`, `systemc`, `verilator`, `vhdl-ls`, `vtr`, `xschem`, `yosys`, and `yosys-slang` follow upstream branch commits; their numbered companions stay fixed to release-series packages.

Fixed release slots and forwarded aliases include `sv-lang_9`, `sv-lang_10`, `sv-lang_11`, `verilator_5`, `systemc_2`, `systemc_3`, `yosys_0`, `vtr_9`, `eqy_0`, `sv2v_0`, `chisel_7`, `chipyard_1`, `hotspot_7`, `spike_1`, `vhdl-ls_0`, `xschem_3`, `cocotb_2`, `edalize_0`, `cacti_6`, and `cacti_7`.

### Python packages

`cocotb` and `edalize` are Python packages. Compose them into a python
environment for actual use rather than adding them directly to `packages`:

```nix
pkgs.python3.withPackages (ps: [ pkgs.nixchip.cocotb_2 pkgs.nixchip.edalize_0 ])
```

### Tool groups

Tool groups are `symlinkJoin` bundles for easy shell composition:

| Group | Contents |
|---|---|
| `simulation-tools` | verilator, sv-lang, chisel, systemc (3.x), ghdl, nvc, iverilog, gtkwave, surfer, verible, spike, vhdl-ls |
| `formal-tools` | yosys-full, sby, eqy, yices, boolector, bitwuzla, cadical, cryptominisat, cvc5, z3, abc, aiger, btor2tools, mcy |
| `fpga-tools` | yosys-full, yosys-slang, nextpnr, icestorm, trellis, openfpgaloader, sv2v, vtr, fusesoc, sby |
| `physical-design-tools` | openroad, openroad-flow-scripts, openroad-flow-scripts-wrapper, yosys-full, circt, firrtl, klayout, magic-vlsi, netgen-vlsi, (espresso if unfree) |
| `analog-tools` | ngspice, xyce, qucs-s, xschem |
| `memory-tools` | cacti, dramsim3, mcpat |
| `thermal-tools` | hotspot, dramsim3 |
| `asic-tools` | physical-design-tools + analog-tools + memory-tools + thermal-tools + formal-tools |
| `hardware-tools` | simulation-tools + fpga-tools + asic-tools + chipyard + surelog + uhdm |

`physical-design-tools` includes the unfree nixpkgs `espresso` package only
when nixpkgs is imported with `allowUnfree = true`.

`systemc_2` is not in `simulation-tools` (which uses `systemc_3`) to avoid
header/library collisions. Use `systemc_2` directly as a standalone package or
via the `versions` shell.

## Dev shells

| Shell | Contents |
|---|---|
| `default` / `hardware` | `hardware-tools` + general dev tools |
| `simulation` | `simulation-tools` + general dev tools |
| `fpga` | `fpga-tools` + `simulation-tools` + general dev tools |
| `asic` | `asic-tools` + `simulation-tools` + general dev tools |
| `versions` | verilator_3/4/5, systemc_2/3, sv-lang_9/10/11, yosys_0, yosys-full_0, cacti_6/7 |

General dev tools included in all shells: `bash`, `git`, `gnumake`, `nodejs`,
`python3`, `shellcheck`, `shfmt`.

Upstream Verilator's canonical GitHub tag history starts at `v3.600`, so this
flake does not publish misleading `verilator1` or `verilator2` packages.

Workspace-style packages install immutable sources under `share/` and provide
`*-init` commands to copy a writable workspace into the current directory.

`yosys-slang0` installs `slang.so` under its own output and provides a
`yosys-slang` wrapper that loads the plugin into the pinned nixpkgs Yosys.

## Custom derivation notes

- **`systemc_2` / `systemc_3`**: built from `accellera-official/systemc`. Version
  determines the C++ standard automatically (2.x → C++14, 3.x → C++17).
- **`vtr_9`**: built with `fetchSubmodules = true` (requires Catch2 and sockpp
  submodules). Parmys, ODIN-II, analytic placement, capnproto, and graphics are
  disabled for a minimal portable build.
- **`eqy_0`**: YosysHQ equivalence checker pinned to upstream `v0.66`. Builds
  three `.so` Yosys plugins and patches Python shebang + template variables.

## Automation

GitHub Actions workflows:

- `CI`: evaluates the flake and builds the fast package set on Linux.
- `Update flake inputs`: runs `nix flake update` weekly and opens or updates a PR.
- `Update package pins`: runs `nix-update -F` for custom hardware packages, evaluates `nix flake check --no-build`, and opens or updates a PR.
- `GitHub Pages`: publishes a searchable package browser from flake metadata.

Branch-tracking packages always use the `unstable-YYYY-MM-DD` version format (no
tag prefix). Released version pins use standard semver (e.g. `0.62`, `26Q2`).

The update script (`scripts/update-packages.sh`) accepts per-package
`--version-regex` constraints via `nixchipUpdateFlags` to keep packages on
their intended major version series (e.g., `systemc_2` stays on 2.x).

Set `NIXCHIP_UPDATE_HISTORICAL=1` to also update historical version pins
(`cacti_6`, `cacti_7`, `verilator_3`, `verilator_4`) — excluded by default because
they are intentionally frozen.

The package browser is generated by `scripts/generate-package-index.py` from the
current flake outputs and the static frontend in `site/index.html`.
