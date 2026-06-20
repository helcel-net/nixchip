# nixchip

`nixchip` is a Nix flake for open hardware development. Hardware packages live
under `pkgs/`; general development tools such as Python, Node.js, Git, Make, and
shell linters come directly from nixpkgs in the dev shells.

## Quick start

```sh
nix develop github:your-org/nixchip
nix develop github:your-org/nixchip#simulation
nix develop github:your-org/nixchip#fpga
nix develop github:your-org/nixchip#asic
```

## Use as a flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixchip.url = "github:your-org/nixchip";
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
  nixchip = builtins.getFlake "github:your-org/nixchip";
  system = builtins.currentSystem;
  pkgs = nixchip.legacyPackages.${system};
in
pkgs.mkShellNoCC {
  packages = [
    pkgs.nixchip.hardware-tools
  ];
}
```

Then run:

```sh
nix-shell --experimental-features 'nix-command flakes'
```

## Packages

Package layout:

- `pkgs/default.nix` wires the hardware package set together.
- `pkgs/cacti/default.nix` builds CACTI `6.5.0` and pinned CACTI 7.
- `pkgs/chisel/default.nix` packages Chisel 7 source and development helpers.
- `pkgs/chipyard/default.nix` packages Chipyard `1.13.0` and provides `chipyard-init`.
- `pkgs/dramsim3/default.nix` builds DRAMsim3 for memory-system simulation.
- `pkgs/hotspot/default.nix` builds HotSpot 7 for thermal modeling.
- `pkgs/mcpat/default.nix` builds McPAT 1 for architectural power, area, and timing modeling.
- `pkgs/openroad-flow-scripts/default.nix` packages OpenROAD Flow Scripts `26Q2` and provides `openroad-flow-scripts-init`.
- `pkgs/verilator/default.nix` builds source-pinned historical Verilator majors.
- `pkgs/yosys-slang/default.nix` builds the `povik/yosys-slang` Yosys plugin from source.
- Non-hardware tools stay in shell composition and come from nixpkgs.

Important package attributes:

- `verilator`: alias for the latest packaged Verilator major.
- `verilator3`: Verilator `3.926`, the latest upstream `3.x` tag.
- `verilator4`: Verilator `4.228`, the latest upstream `4.x` tag.
- `verilator5`: Verilator from the pinned nixpkgs input.
- `yosys`: alias for `yosys0`.
- `yosys0`, `yosys-full0`, `yosys-full`.
- `sv-lang`: alias for `sv-lang11`.
- `sv-lang9`, `sv-lang10`, `sv-lang11`, `slang`.
- `openroad`: alias for `openroad26`.
- `openroad26`.
- `openroad-flow-scripts`: alias for `openroad-flow-scripts26`.
- `openroad-flow-scripts26`.
- `circt`: alias for `circt1`.
- `circt1`, `firrtl1`, `firrtl`.
- `cacti`: alias for `cacti7`.
- `cacti6`: CACTI `6.5.0`.
- `cacti7`: CACTI 7 pinned to HewlettPackard/cacti commit `1ffd8df`.
- `chipyard`: alias for `chipyard1`.
- `chipyard1`.
- `yosys-slang`: alias for `yosys-slang0`.
- `yosys-slang0`: `povik/yosys-slang` pinned to commit `009058e`.
- `chisel`: alias for `chisel7`.
- `chisel7`: Chisel `7.13.0`, with `chisel-init`, `chisel-path`, `chisel-scala-cli`, `chisel-mill`, and `chisel-sbt`.
- `verible`: alias for `verible0`.
- `verible0`: Verible from the pinned nixpkgs input.
- `systemc`: alias for `systemc3`.
- `systemc3`: SystemC from the pinned nixpkgs input.
- `ghdl`: alias for `ghdl6`.
- `ghdl6`: GHDL from the pinned nixpkgs input.
- `nvc`: alias for `nvc1`.
- `nvc1`: NVC from the pinned nixpkgs input.
- `surfer`: alias for `surfer0`.
- `surfer0`: Surfer waveform viewer from the pinned nixpkgs input.
- `ngspice`: alias for `ngspice45`.
- `ngspice45`: ngspice 45 from the pinned nixpkgs input.
- `xyce`: alias for `xyce7`.
- `xyce7`: Xyce 7 from the pinned nixpkgs input.
- `qucs-s`: alias for `qucs-s25`.
- `qucs-s25`: Qucs-S 25 from the pinned nixpkgs input.
- `surelog`: alias for `surelog1`.
- `surelog1`: Surelog from the pinned nixpkgs input.
- `uhdm`: alias for `uhdm1`.
- `uhdm1`: UHDM from the pinned nixpkgs input.
- `netgen-vlsi`: alias for `netgen-vlsi1`.
- `netgen-vlsi1`: Netgen LVS from the pinned nixpkgs input.
- `klayout`: alias for `klayout0`.
- `klayout0`: KLayout from the pinned nixpkgs input.
- `magic-vlsi`: alias for `magic-vlsi8`.
- `magic-vlsi8`: Magic VLSI from the pinned nixpkgs input.
- `sby`: alias for `sby0`.
- `sby0`: SBY from the pinned nixpkgs input.
- `yices`: alias for `yices2`.
- `yices2`: Yices 2 from the pinned nixpkgs input.
- `boolector`: alias for `boolector3`.
- `boolector3`: Boolector 3 from the pinned nixpkgs input.
- `bitwuzla`: alias for `bitwuzla0`.
- `bitwuzla0`: Bitwuzla from the pinned nixpkgs input.
- `cadical`: alias for `cadical3`.
- `cadical3`: CaDiCaL 3 from the pinned nixpkgs input.
- `cryptominisat`: alias for `cryptominisat5`.
- `cryptominisat5`: CryptoMiniSat 5 from the pinned nixpkgs input.
- `hotspot`: alias for `hotspot7`.
- `hotspot7`: HotSpot 7, built from `uvahotspot/HotSpot`.
- `dramsim3`: alias for `dramsim3-1`.
- `dramsim3-1`: DRAMsim3 1, built from `umd-memsys/DRAMsim3`.
- `mcpat`: alias for `mcpat1`.
- `mcpat1`: McPAT 1, built from `HewlettPackard/mcpat`.
- `simulation-tools`, `formal-tools`, `fpga-tools`, `physical-design-tools`, `analog-tools`, `memory-tools`, `thermal-tools`, `asic-tools`, `hardware-tools`.

`physical-design-tools` includes the unfree nixpkgs `espresso` package only
when nixpkgs is imported with `allowUnfree = true`.

Upstream Verilator's canonical GitHub tag history starts at `v3.600`, so this
flake does not publish misleading `verilator1` or `verilator2` packages.

Workspace-style packages install immutable sources under `share/` and provide
`*-init` commands to copy a writable workspace into the current directory.

`yosys-slang0` installs `slang.so` under its own output and provides a
`yosys-slang` wrapper that loads the plugin into the pinned nixpkgs Yosys.

## Automation

GitHub Actions workflows:

- `CI`: evaluates the flake and builds the fast package set on Linux.
- `Update flake inputs`: runs `nix flake update` weekly and opens or updates a PR.
- `Update package pins`: runs `nix-update -F --build` for custom hardware packages and opens or updates a PR.
- `GitHub Pages`: publishes a searchable package browser from flake metadata.

The package browser is generated by `scripts/generate-package-index.py` from the
current flake outputs and the static frontend in `site/index.html`.
