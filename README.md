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
nix develop github:helcel-net/nixchip#versions     # side-by-side verilator3/4/5, systemc2/3, etc.
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
          pkgs.nixchip.verilator4
        ];
        shellHook = nixchip.lib.mkNixchipVarsHook pkgs.nixchip;
      };
    };
}
```

The overlay exports packages under both `pkgs.nixchip.*` and top-level package
names such as `pkgs.verilator4`.

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
verilator4       → VERILATOR4_HOME / VERILATOR4_BIN / VERILATOR4_LIB / VERILATOR4_INCLUDE
systemc2         → SYSTEMC2_HOME / SYSTEMC2_BIN / SYSTEMC2_LIB / SYSTEMC2_INCLUDE
sv-lang9         → SV_LANG9_HOME / SV_LANG9_BIN / ...
yosys-full0      → YOSYS_FULL0_HOME / YOSYS_FULL0_BIN / ...
btor2tools0      → BTOR2TOOLS0_HOME / ...
qucs-s25         → QUCS_S25_HOME / ...
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
| `verilator3` | 3.926 | Verilator 3.x — latest upstream 3.x tag |
| `verilator4` | 4.228 | Verilator 4.x — latest upstream 4.x tag |
| `systemc2` | 2.3.4 | SystemC 2.x (accellera-official/systemc, C++14) |
| `systemc3` | 3.0.2 | SystemC 3.x (accellera-official/systemc, C++17) |
| `vtr9` | 9.0.0 | Verilog-to-Routing — VPR place-and-route |
| `eqy0` | 0.66 | YosysHQ equivalence checker |
| `yosys-slang0` | — | povik/yosys-slang Yosys plugin |
| `chisel7` | 7.x | Chisel 7 with `chisel-init`, `chisel-scala-cli`, `chisel-mill`, `chisel-sbt` |
| `chipyard1` | 1.x | Chipyard SoC framework with `chipyard-init` |
| `openroad-flow-scripts26` | 26Q2 | OpenROAD Flow Scripts with `openroad-flow-scripts-init` |
| `hotspot7` | 7 | HotSpot thermal modeling (uvahotspot/HotSpot) |
| `dramsim3-1` | 1 | DRAMsim3 memory simulator (umd-memsys/DRAMsim3) |
| `mcpat1` | 1 | McPAT power/area/timing model (HewlettPackard/mcpat) |
| `cacti6` | 6.5.0 | CACTI 6 cache/memory model |
| `cacti7` | 7 pinned | CACTI 7 (HewlettPackard/cacti commit `1ffd8df`) |

### Forwarded from nixpkgs (version-tracked)

| Attribute | Alias of | Description |
|---|---|---|
| `verilator5` | `basePkgs.verilator` | Verilator from nixpkgs |
| `yosys0`, `yosys-full0` | `basePkgs.yosys` | Yosys (full = with GHDL plugin if available) |
| `sv-lang9` | `basePkgs.sv-lang_9` | LLVM/slang SystemVerilog compiler 9.x |
| `sv-lang10` | `basePkgs.sv-lang_10` | slang 10.x |
| `sv-lang11` | `basePkgs.sv-lang` | slang 11.x (latest) |
| `abc0` | `basePkgs.abc-verifier` | Fixed ABC logic synthesis and verification release |
| `sv2v0` | `basePkgs.haskellPackages.sv2v` | SystemVerilog-to-Verilog converter |
| `ghdl6` | 6.0.0 | Fixed GHDL 6 release |
| `nvc1` | `basePkgs.nvc` | NVC VHDL compiler/simulator |
| `vhdl-ls0` | `basePkgs.vhdl-ls` | VHDL language server |
| `spike1` | `basePkgs.spike` | RISC-V ISA simulator |
| `surfer0` | `basePkgs.surfer` | Surfer waveform viewer |
| `verible0` | `basePkgs.verible` | SystemVerilog linter and formatter |
| `surelog1` | `basePkgs.surelog` | SystemVerilog preprocessor and elaborator |
| `uhdm1` | `basePkgs.uhdm` | Universal Hardware Data Model |
| `openroad26` | `basePkgs.openroad` | OpenROAD physical design suite |
| `circt1` | `basePkgs.circt` | CIRCT / MLIR circuit IR tools |
| `firrtl1` | `basePkgs.firrtl` | Fixed FIRRTL 1.x compiler release |
| `klayout0` | `basePkgs.klayout` | KLayout GDSII viewer and editor |
| `magic-vlsi8` | `basePkgs.magic-vlsi` | Magic VLSI layout tool |
| `netgen-vlsi1` | `basePkgs.netgen-vlsi` | Netgen LVS tool |
| `ngspice45` | `basePkgs.ngspice` | ngspice circuit simulator |
| `xyce7` | `basePkgs.xyce` | Xyce parallel circuit simulator |
| `qucs-s25` | `basePkgs.qucs-s` | Qucs-S schematic-driven simulator |
| `xschem3` | `basePkgs.xschem` | Xschem schematic editor |
| `fusesoc2` | `basePkgs.fusesoc` | Fixed FuseSoC 2.x release |
| `cocotb2` | `basePkgs.python3Packages.cocotb` | Python co-simulation framework |
| `edalize0` | `basePkgs.python3Packages.edalize` | EDA tool abstraction library |
| `sby0` | `basePkgs.sby` | SymbiYosys formal verification front-end |
| `yices2` | `basePkgs.yices` | Yices 2 SMT solver |
| `boolector3` | `basePkgs.boolector` | Boolector SMT solver |
| `bitwuzla0` | `basePkgs.bitwuzla` | Bitwuzla SMT solver |
| `cadical3` | `basePkgs.cadical` | CaDiCaL SAT solver |
| `cryptominisat5` | `basePkgs.cryptominisat` | CryptoMiniSat SAT solver |
| `aiger1` | `basePkgs.aiger` | Fixed AIGER 1.x AIG format tools release |
| `btor2tools0` | `basePkgs.btor2tools` | BTOR2 word-level model checking tools |
| `mcy0` | `basePkgs.mcy` | YosysHQ mutation cover for formal tests |

Branch-tracking defaults: `verilator`, `systemc`, `ghdl`, `yosys`, `sv-lang`, `slang`, `yosys-slang`, `abc`, `sv2v`, `firrtl`, `gtkwave`, `spike`, `vhdl-ls`, `vtr`, `fusesoc`, `openroad`, `openroad-flow-scripts`, `eqy`, `aiger`, `cacti`, `xschem`, `cocotb`, `edalize`, and `amaranth` follow upstream branch commits; their numbered companions stay fixed to release-series packages.

Fixed aliases: `sv-lang9`, `sv-lang10`, `sv-lang11`, `verilator5`, `systemc3`, `yosys0`, `vtr9`, `eqy0`, `sv2v0`, `spike1`, `vhdl-ls0`, `xschem3`, `cocotb2`, `edalize0`, `cacti7`, etc.

### Python packages

`cocotb` and `edalize` are Python packages. Compose them into a python
environment for actual use rather than adding them directly to `packages`:

```nix
pkgs.python3.withPackages (ps: [ pkgs.nixchip.cocotb2 pkgs.nixchip.edalize0 ])
```

### Tool groups

Tool groups are `symlinkJoin` bundles for easy shell composition:

| Group | Contents |
|---|---|
| `simulation-tools` | verilator, sv-lang, chisel, systemc (3.x), ghdl, nvc, iverilog, gtkwave, surfer, verible, spike, vhdl-ls |
| `formal-tools` | yosys-full, sby, eqy, yices, boolector, bitwuzla, cadical, cryptominisat, cvc5, z3, abc, aiger, btor2tools, mcy |
| `fpga-tools` | yosys-full, yosys-slang, nextpnr, icestorm, trellis, openfpgaloader, sv2v, vtr, fusesoc, sby |
| `physical-design-tools` | openroad, openroad-flow-scripts, yosys-full, circt, firrtl, klayout, magic-vlsi, netgen-vlsi, (espresso if unfree) |
| `analog-tools` | ngspice, xyce, qucs-s, xschem |
| `memory-tools` | cacti, dramsim3, mcpat |
| `thermal-tools` | hotspot, dramsim3 |
| `asic-tools` | physical-design-tools + analog-tools + memory-tools + thermal-tools + formal-tools |
| `hardware-tools` | simulation-tools + fpga-tools + asic-tools + chipyard + surelog + uhdm |

`physical-design-tools` includes the unfree nixpkgs `espresso` package only
when nixpkgs is imported with `allowUnfree = true`.

`systemc2` is not in `simulation-tools` (which uses `systemc3`) to avoid
header/library collisions. Use `systemc2` directly as a standalone package or
via the `versions` shell.

## Dev shells

| Shell | Contents |
|---|---|
| `default` / `hardware` | `hardware-tools` + general dev tools |
| `simulation` | `simulation-tools` + general dev tools |
| `fpga` | `fpga-tools` + `simulation-tools` + general dev tools |
| `asic` | `asic-tools` + `simulation-tools` + general dev tools |
| `versions` | verilator3/4/5, systemc2/3, sv-lang9/10/11, yosys0, yosys-full0, cacti6/7 |

General dev tools included in all shells: `bash`, `git`, `gnumake`, `nodejs`,
`python3`, `shellcheck`, `shfmt`.

Upstream Verilator's canonical GitHub tag history starts at `v3.600`, so this
flake does not publish misleading `verilator1` or `verilator2` packages.

Workspace-style packages install immutable sources under `share/` and provide
`*-init` commands to copy a writable workspace into the current directory.

`yosys-slang0` installs `slang.so` under its own output and provides a
`yosys-slang` wrapper that loads the plugin into the pinned nixpkgs Yosys.

## Custom derivation notes

- **`systemc2` / `systemc3`**: built from `accellera-official/systemc`. Version
  determines the C++ standard automatically (2.x → C++14, 3.x → C++17).
- **`vtr9`**: built with `fetchSubmodules = true` (requires Catch2 and sockpp
  submodules). Parmys, ODIN-II, analytic placement, capnproto, and graphics are
  disabled for a minimal portable build.
- **`eqy0`**: YosysHQ equivalence checker pinned to upstream `v0.66`. Builds
  three `.so` Yosys plugins and patches Python shebang + template variables.

## Automation

GitHub Actions workflows:

- `CI`: evaluates the flake and builds the fast package set on Linux.
- `Update flake inputs`: runs `nix flake update` weekly and opens or updates a PR.
- `Update package pins`: runs `nix-update -F --build` for custom hardware packages and opens or updates a PR.
- `GitHub Pages`: publishes a searchable package browser from flake metadata.

The update script (`scripts/update-packages.sh`) accepts per-package
`--version-regex` constraints via `package_extra_flags` to keep packages on
their intended major version series (e.g., `systemc2` stays on 2.x).

Set `NIXCHIP_UPDATE_HISTORICAL=1` to also update historical version pins
(`cacti6`, `cacti7`, `verilator3`, `verilator4`) — excluded by default because
they are intentionally frozen.

The package browser is generated by `scripts/generate-package-index.py` from the
current flake outputs and the static frontend in `site/index.html`.
