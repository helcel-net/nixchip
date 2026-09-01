{
  description = ''
    Flux dev environment. No venv, no pip install step: `nix develop` alone works. Shells:
      - `python` (fast): Python/Rust/Docker base.
      - `default` (full): adds the EDA tools and prebuilt simulators the adapters need.
      - `timeloop` (linux): hermetic Timeloop v4 + Accelergy.
      - `physical` (linux): the OpenROAD place-and-route rung.

    Almost everything third-party comes prebuilt from nixchip — the DSE Python stack
    (zigzag-dse, stream-dse), CHIA, Timeloop/Accelergy, the simulators (Booksim2, Noxim,
    3D-ICE, gem5, CACTI, DRAMsim3) and the EDA tools (Verilator, Yosys, OpenROAD). `nixpkgs`
    follows nixchip's pin, so binaries substitute from the nixchip0 Cachix caches and
    cache.nixos.org; run nix with `--accept-flake-config`.

    The local `flux-*` packages are deliberately NOT derivations: they are actively edited,
    and packaging them immutably would force a flake rebuild before every test run. The
    shellHook puts each `src/` on PYTHONPATH instead — editable-install equivalent, without
    pip. `localSrcDirs` is the authoritative list;
    `tests/unit/test_flake_local_packages.py` checks it against the filesystem.

    The Timeloop adapter defaults to Docker regardless of shell — `FLUX_TIMELOOP_LOCAL=1`
    opts into the hermetic path, which reproduces the pinned Docker energy numbers (D206).

    `default` cherry-picks Verilator/Yosys rather than using nixchip's `simulation`/`asic`
    bundles: both pull in `cryptominisat`, whose build git-clones `cadical` at build time
    and so cannot work in nix's sandbox.
  '';

  inputs = {
    # Follow nixchip's nixpkgs pin — overriding it (the old
    # `nixchip.inputs.nixpkgs.follows`) rewrites every nixchip derivation hash and forfeits
    # all binary-cache hits.
    nixchip.url = "github:helcel-net/nixchip";
    nixpkgs.follows = "nixchip/nixpkgs";
  };

  outputs = { self, nixpkgs, nixchip }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          chipPkgs = nixchip.packages.${system};

          # Shared by pythonEnv and the timeloop shell's env. `import onnx` comes via
          # zigzag-dse's propagated PyPI-wheel onnx; do NOT add ps.onnx alongside — the
          # nixpkgs build's libprotobuf clashes with ortools' vendored one and SIGSEGVs (D80).
          basePythonPackages = ps: [
            ps.pytest
            ps.jsonschema
            ps.pyyaml
            chipPkgs.zigzag-dse
            chipPkgs.stream-dse
            chipPkgs.chia # propagates ray's [default] extras
            # Direct deps of flows/chia_nodes, flows/mcp, search/agentic.
            ps.openai
            ps.uvicorn
          ];
          pythonEnv = pkgs.python3.withPackages basePythonPackages;

          # manylinux wheels (numpy, onnx, ...) dlopen libstdc++/zlib at import time;
          # nixpkgs' Python doesn't put them on the default linker path.
          nativeLibPath = pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.zlib ];

          # The local flux-* packages, src/-only — `pip install -e` equivalent for all of
          # them at once, adapters included: PYTHONPATH costs nothing until imported (D123).
          localSrcDirs = [
            "core/ir/src"
            "evaluator/abi/src"
            "evaluator/zigzag/src"
            "evaluator/timeloop/src"
            "evaluator/stream/src"
            "core/stores/src"
            "interfaces/cli/src"
            "core/frontends/onnx/src"
            "evaluator/calibration/src"
            "evaluator/validity/src"
            "evaluator/rtl/src"
            "evaluator/systemc/src"
            "mentor/knowledge/src"
            "mentor/knowledge/mining/src"
            "core/llm/src"
            "core/profile/src"
            "mentor/protocols/src"
            "orchestrator/exhaustive/src"
            "orchestrator/annealing/src"
            "orchestrator/agentic/src"
            "orchestrator/architecture/src"
            "orchestrator/campaign/src"
            "orchestrator/directed/src"
            "evaluator/openroad/src"
            "evaluator/interconnect_struct/src"
            "evaluator/interconnect_phys/src"
            "applications/interconnect/lib/src"
            "interfaces/chia_nodes/src"
            "interfaces/mcp/src"
            "generator/harness_systemc/src"
            "generator/harness_rtl/src"
            "core/workload_dynamism/src"
            "generator/design/src"
            "evaluator/redaction/src"
            "evaluator/thermal/src"
            "evaluator/dramsim3/src"
            "evaluator/native/src"
            "evaluator/booksim/src"
            "evaluator/noxim/src"
            "evaluator/cacti/src"
            "evaluator/gem5/src"
          ];

          shellHook = ''
            export PYTHONPATH="${pkgs.lib.concatStringsSep ":" (map (d: "$PWD/${d}") localSrcDirs)}:$PYTHONPATH"
            mkdir -p .nix-bin
            printf '#!/usr/bin/env bash\nexec python3 -c "from flux_cli.main import main; main()" "$@"\n' > .nix-bin/flux
            chmod +x .nix-bin/flux
            export PATH="$PWD/.nix-bin:$PATH"
            # Prebuilt CACTI/DRAMsim3 (D146/D148). Adapters fall back to cloning when these
            # are unset, and a caller's own value wins.
            export CACTI_BIN="''${CACTI_BIN:-${chipPkgs.cacti}/bin}"
            export DRAMSIM3_BIN="''${DRAMSIM3_BIN:-${chipPkgs.dramsim3_}/bin}"
            echo "flux dev shell: python $(python3 --version), no venv/pip install needed"
            echo "  python -m pytest -q     # run tests directly"
            echo "  flux --help              # the flux-cli console script (wrapper, see flake.nix)"
          '';
        in
        {
          python = pkgs.mkShell {
            name = "flux-dev-python";
            packages = [ pythonEnv pkgs.rustc pkgs.cargo pkgs.docker-client ];
            LD_LIBRARY_PATH = nativeLibPath;
            inherit shellHook;
          };
        }
        # Timeloop and OpenROAD are linux-only; these shells exist only on linux.
        // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          timeloop = pkgs.mkShell {
            name = "flux-dev-timeloop";
            packages = [
              (pkgs.python3.withPackages (ps: basePythonPackages ps ++ [
                chipPkgs.timeloopfe chipPkgs.accelergy
                chipPkgs.accelergy-library-plug-in chipPkgs.accelergy-cacti-plug-in
              ]))
              chipPkgs.timeloop pkgs.rustc pkgs.cargo pkgs.docker-client
            ];
            LD_LIBRARY_PATH = nativeLibPath;
            shellHook = ''
              echo "flux dev shell (timeloop: hermetic Timeloop v4 + Accelergy, no Docker)"
              echo "  FLUX_TIMELOOP_LOCAL=1   # opt in; the adapter defaults to Docker regardless"
            '' + shellHook;
          };

          # The OpenROAD place-and-route rung (D225), with Verilator for the
          # composition-frontier tests (D246), yosys-slang as SV front end (D276), and
          # OpenRAM as the CACTI cross-check (D260).
          physical = pkgs.mkShell {
            name = "flux-dev-physical";
            packages = [
              pythonEnv pkgs.rustc pkgs.cargo
              chipPkgs.yosys chipPkgs.openroad chipPkgs.verilator
              chipPkgs.yosys-slang chipPkgs.openram-wrapper
            ];
            LD_LIBRARY_PATH = nativeLibPath;
            # Yosys only finds plugins under its own share/yosys/plugins. Exported rather
            # than hard-coded so the flow falls back to the built-in reader when absent.
            YOSYS_SLANG_PLUGIN = "${chipPkgs.yosys-slang}/share/yosys/plugins/slang.so";
            shellHook = ''
              echo "flux dev shell (physical: yosys + openroad on ASAP7, slang SV frontend)"
            '' + shellHook;
          };
        }
        // {
          default = pkgs.mkShell {
            name = "flux-dev-full";
            packages = [
              pythonEnv pkgs.rustc pkgs.cargo pkgs.docker-client
              chipPkgs.verilator chipPkgs.yosys chipPkgs.gtkwave
              # Prebuilt so the adapters skip clone-and-build; nixchip names DRAMsim3
              # `dramsim3_` and 3D-ICE `threed-ice`.
              chipPkgs.cacti chipPkgs.dramsim3_
            ]
            # gem5 and 3D-ICE are linux-only; referencing them on darwin fails evaluation.
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
              chipPkgs.booksim2 chipPkgs.noxim chipPkgs.threed-ice chipPkgs.gem5_
            ]
            ++ [
              # systemc replaces a system libsystemc-dev (D31/D39); flex/bison/cmake/unzip/
              # openblasCompat serve only the adapters' clone-and-build fallback, used when
              # the *_BIN overrides are unset (D25/D32/D64).
              pkgs.systemc pkgs.flex pkgs.bison pkgs.cmake pkgs.unzip pkgs.openblasCompat
            ];
            LD_LIBRARY_PATH = nativeLibPath;
            shellHook = pkgs.lib.optionalString pkgs.stdenv.isLinux ''
              # Same defensive pattern as CACTI_BIN: adapters skip clone-and-build, and a
              # caller's own value wins.
              export BOOKSIM_BIN="''${BOOKSIM_BIN:-${chipPkgs.booksim2}/bin}"
              export NOXIM_BIN="''${NOXIM_BIN:-${chipPkgs.noxim}/bin}"
              export NOXIM_SHARE="''${NOXIM_SHARE:-${chipPkgs.noxim}/share/noxim}"
              export THREED_ICE_BIN="''${THREED_ICE_BIN:-${chipPkgs.threed-ice}/bin}"
              export GEM5_BIN="''${GEM5_BIN:-${chipPkgs.gem5_}/bin}"
            '' + ''
              echo "flux dev shell (full: python + rust + Verilator/Yosys/GTKWave/SystemC + simulators)"
              echo "For Phase 1 work only, prefer: nix develop .#python (faster, smaller closure)"
            '' + shellHook;
          };
        });
    };
}
