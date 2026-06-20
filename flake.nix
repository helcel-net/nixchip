{
  description = "Nix packages and shells for open hardware development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f system);

      overlays.default =
        final: prev:
        import ./pkgs {
          pkgs = final;
          basePkgs = prev;
        };

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

      # Generate a shellHook that exports PKGNAME_HOME / _BIN / _LIB / _INCLUDE
      # for every individual nixchip package (tool-group bundles and Python-only
      # libraries are excluded).  Paths are baked in at evaluation time so no
      # runtime lookup is required; the variables are always set, even if the
      # package was not requested in this shell's `packages` list (in which case
      # the path simply won't be populated until it is built).
      mkNixchipVarsHook =
        hardware:
        let
          pkgsToExport = lib.filterAttrs (
            name: _:
            !lib.hasSuffix "-tools" name
            && !builtins.elem name [
              "cocotb"
              "cocotb2"
              "edalize"
              "edalize0"
            ]
          ) hardware;
        in
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: pkg:
            let
              envPrefix = lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] name);
            in
            ''
              export ${envPrefix}_HOME="${pkg}"
              export ${envPrefix}_BIN="${pkg}/bin"
              export ${envPrefix}_LIB="${pkg}/lib"
              export ${envPrefix}_INCLUDE="${pkg}/include"
            ''
          ) pkgsToExport
        );
    in
    {
      inherit overlays;

      # Exported for downstream flakes so they can call mkNixchipVarsHook
      # on their own pkgs.nixchip attribute set.
      lib = { inherit mkNixchipVarsHook; };

      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          hardware = pkgs.nixchip;
        in
        # Guard against accidental non-derivation attributes leaking in.
        lib.filterAttrs (_: lib.isDerivation) hardware
        // {
          default = hardware.hardware-tools;
        }
      );

      legacyPackages = forAllSystems mkPkgs;

      devShells = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          hardware = pkgs.nixchip;

          nonHardwareTools = with pkgs; [
            bashInteractive
            git
            gnumake
            nodejs
            python3
            shellcheck
            shfmt
          ];

          varsHook = mkNixchipVarsHook hardware;
        in
        {
          # Full hardware toolbox + env vars for every package.
          default = pkgs.mkShellNoCC {
            packages = [ hardware.hardware-tools ] ++ nonHardwareTools;
            shellHook = varsHook;
          };

          hardware = pkgs.mkShellNoCC {
            packages = [ hardware.hardware-tools ] ++ nonHardwareTools;
            shellHook = varsHook;
          };

          simulation = pkgs.mkShellNoCC {
            packages = [ hardware.simulation-tools ] ++ nonHardwareTools;
            shellHook = varsHook;
          };

          fpga = pkgs.mkShellNoCC {
            packages = [
              hardware.fpga-tools
              hardware.simulation-tools
            ] ++ nonHardwareTools;
            shellHook = varsHook;
          };

          asic = pkgs.mkShellNoCC {
            packages = [
              hardware.asic-tools
              hardware.simulation-tools
            ] ++ nonHardwareTools;
            shellHook = varsHook;
          };

          # Side-by-side versioned packages for comparing tool generations.
          # Every *_HOME / *_BIN / *_LIB / *_INCLUDE variable is guaranteed
          # to point to a built path when this shell is entered.
          versions = pkgs.mkShellNoCC {
            packages =
              with hardware;
              [
                # Verilator majors
                verilator3
                verilator4
                verilator5
                # SystemC series
                systemc2
                systemc3
                # sv-lang / slang generations
                sv-lang9
                sv-lang10
                sv-lang11
                # Synthesis
                yosys0
                yosys-full0
                # CACTI memory model generations
                cacti6
                cacti7
              ]
              ++ nonHardwareTools;
            shellHook = varsHook;
          };
        }
      );

      formatter = forAllSystems (system: (mkPkgs system).nixfmt);
    };
}
