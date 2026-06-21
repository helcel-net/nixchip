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

      # Exports PKGNAME_{HOME,BIN,LIB,INCLUDE} for every individual nixchip
      # package. Tool-group bundles and Python packages are excluded.
      mkNixchipVarsHook =
        hw:
        let
          pythonPackages = [
            "amaranth"
            "amaranth0"
            "cocotb"
            "cocotb2"
            "edalize"
            "edalize0"
          ];
          pkgsToExport = lib.filterAttrs (
            name: pkg:
            lib.isDerivation pkg
            && !lib.hasSuffix "-tools" name
            && !builtins.elem name pythonPackages
          ) hw;
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
          hw = pkgs.nixchip;
        in
        lib.filterAttrs (_: lib.isDerivation) hw // { default = hw.hardware-tools; }
      );

      legacyPackages = forAllSystems mkPkgs;

      devShells = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          hw = pkgs.nixchip;

          nonHardwareTools = with pkgs; [
            bashInteractive
            git
            gnumake
            nodejs
            python3
            shellcheck
            shfmt
          ];

          varsHook = mkNixchipVarsHook hw;
        in
        rec {
          hardware = pkgs.mkShellNoCC {
            packages = [ hw.hardware-tools ] ++ nonHardwareTools;
            shellHook = varsHook;
          };
          default = hardware;

          simulation = pkgs.mkShellNoCC {
            packages = [ hw.simulation-tools ] ++ nonHardwareTools;
            shellHook = varsHook;
          };

          fpga = pkgs.mkShellNoCC {
            packages = [
              hw.fpga-tools
              hw.simulation-tools
            ] ++ nonHardwareTools;
            shellHook = varsHook;
          };

          asic = pkgs.mkShellNoCC {
            packages = [
              hw.asic-tools
              hw.simulation-tools
            ] ++ nonHardwareTools;
            shellHook = varsHook;
          };

          # Side-by-side versioned packages for comparing tool generations.
          versions = pkgs.mkShellNoCC {
            packages =
              with hw;
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
