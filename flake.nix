{
  description = "Nix packages and shells for open hardware development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

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
    in
    {
      inherit overlays;

      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          hardware = pkgs.nixchip;
        in
        hardware
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
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              hardware.hardware-tools
            ]
            ++ nonHardwareTools;
          };

          hardware = pkgs.mkShellNoCC {
            packages = [
              hardware.hardware-tools
            ]
            ++ nonHardwareTools;
          };

          simulation = pkgs.mkShellNoCC {
            packages = [
              hardware.simulation-tools
            ]
            ++ nonHardwareTools;
          };

          fpga = pkgs.mkShellNoCC {
            packages = [
              hardware.fpga-tools
              hardware.simulation-tools
            ]
            ++ nonHardwareTools;
          };

          asic = pkgs.mkShellNoCC {
            packages = [
              hardware.asic-tools
              hardware.simulation-tools
            ]
            ++ nonHardwareTools;
          };
        }
      );

      formatter = forAllSystems (system: (mkPkgs system).nixfmt);
    };
}
