# nix-update with a `nix` whose `flake metadata --json` copies the flake into
# the store. nix-update re-evaluates the edited flake through the store path
# that query reports; current Nix reports it without copying, so every real
# version change failed with 'opening file "/nix/store/...-source": No such
# file or directory'. `nix flake archive --json` reports the same "path" and
# does copy. Every other nix command passes through unchanged.
#
# Built from the nixpkgs revision pinned in flake.lock rather than the
# floating `nixpkgs` registry entry, so the updater only changes when the
# lock does (a registry bump silently broke every release update once).
let
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  nixpkgsNode = lock.nodes.${lock.nodes.root.inputs.nixpkgs};
  pkgs = import (builtins.fetchTree nixpkgsNode.locked) {
    system = builtins.currentSystem;
  };
  nix = pkgs.runCommand "nix-flake-metadata-copies" { } ''
    mkdir -p $out/bin
    for f in ${pkgs.nix}/bin/*; do
      ln -s "$f" "$out/bin/$(basename "$f")"
    done
    rm $out/bin/nix
    cat > $out/bin/nix <<EOF
    #!${pkgs.runtimeShell}
    if [ \$# -eq 3 ] && [ "\$1 \$2 \$3" = "flake metadata --json" ]; then
      exec ${pkgs.nix}/bin/nix flake archive --json
    fi
    exec ${pkgs.nix}/bin/nix "\$@"
    EOF
    chmod +x $out/bin/nix
  '';
in
pkgs.nix-update.override { inherit nix; }
