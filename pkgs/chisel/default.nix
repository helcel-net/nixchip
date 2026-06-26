{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  mill,
  sbt,
  scala-cli,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ? if lib.hasPrefix "unstable-" version then "428dbeb35d1059e82823cd8556530bab578f1084" else "v${version}",
  hash ? "sha256-5NpXW+24SN7Wde2d7UnfkmZSGWLNZXRw+D1R/v46HEM=",
}:

stdenvNoCC.mkDerivation {
  pname = "chisel";
  inherit version;

  src = fetchFromGitHub {
    owner = "chipsalliance";
    repo = "chisel";
    inherit rev hash;
  };

  dontPatchShebangs = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/chisel-src" "$out/share/chisel-template/src/main/scala" "$out/bin" "$out/libexec"
    cp -R . "$out/share/chisel-src"

    cat > "$out/share/chisel-template/src/main/scala/Top.scala" <<'EOF'
    //> using scala "2.13.16"
    //> using dep "org.chipsalliance::chisel:VERSION"
    //> using plugin "org.chipsalliance:::chisel-plugin:VERSION"

    import chisel3._
    import circt.stage.ChiselStage

    class Top extends Module {
      val io = IO(new Bundle {
        val a = Input(UInt(8.W))
        val b = Input(UInt(8.W))
        val y = Output(UInt(8.W))
      })

      io.y := io.a + io.b
    }

    object Main extends App {
      ChiselStage.emitSystemVerilogFile(
        new Top,
        firtoolOpts = Array("-disable-all-randomization", "-strip-debug-info")
      )
    }
    EOF
    substituteInPlace "$out/share/chisel-template/src/main/scala/Top.scala" \
      --replace-fail "VERSION" "${version}"

    cat > "$out/share/chisel-template/README.md" <<EOF
    # Chisel ${version} starter

    Run:

    \`\`\`sh
    chisel-scala-cli run .
    \`\`\`

    This template uses \`org.chipsalliance::chisel:${version}\` and the matching
    \`org.chipsalliance:::chisel-plugin:${version}\` compiler plugin.
    EOF

    cat > "$out/libexec/chisel-cache-env" <<'EOF'
    if [ -z "\''${XDG_CACHE_HOME:-}" ] || ! { mkdir -p "$XDG_CACHE_HOME" 2>/dev/null && [ -w "$XDG_CACHE_HOME" ]; }; then
      if [ -n "\''${HOME:-}" ] && mkdir -p "$HOME/.cache" 2>/dev/null && [ -w "$HOME/.cache" ]; then
        export XDG_CACHE_HOME="$HOME/.cache"
      else
        export XDG_CACHE_HOME="$PWD/.cache"
        mkdir -p "$XDG_CACHE_HOME"
      fi
    fi

    if [ -z "\''${COURSIER_CACHE:-}" ]; then
      export COURSIER_CACHE="$XDG_CACHE_HOME/coursier"
      mkdir -p "$COURSIER_CACHE"
    fi

    if [ -z "\''${SCALA_CLI_HOME:-}" ]; then
      export SCALA_CLI_HOME="$XDG_CACHE_HOME/scalacli"
      mkdir -p "$SCALA_CLI_HOME"
    fi
    EOF

    cat > "$out/bin/chisel-path" <<EOF
    #!${stdenvNoCC.shell}
    printf '%s\n' "$out/share/chisel-src"
    EOF

    cat > "$out/bin/chisel-init" <<EOF
    #!${stdenvNoCC.shell}
    set -eu
    target="\''${1:-chisel-${version}-starter}"
    if [ -e "\$target" ]; then
      echo "chisel-init: \$target already exists" >&2
      exit 1
    fi
    cp -R "$out/share/chisel-template" "\$target"
    chmod -R u+w "\$target"
    printf '%s\n' "\$target"
    EOF

    cat > "$out/bin/chisel-scala-cli" <<EOF
    #!${stdenvNoCC.shell}
    . "$out/libexec/chisel-cache-env"
    exec ${scala-cli}/bin/scala-cli "\$@"
    EOF

    cat > "$out/bin/chisel-mill" <<EOF
    #!${stdenvNoCC.shell}
    . "$out/libexec/chisel-cache-env"
    exec ${mill}/bin/mill "\$@"
    EOF

    cat > "$out/bin/chisel-sbt" <<EOF
    #!${stdenvNoCC.shell}
    . "$out/libexec/chisel-cache-env"
    exec ${sbt}/bin/sbt "\$@"
    EOF

    chmod +x "$out/bin/"*

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };
  passthru.nixchipUpdate = true;
  passthru.nixchipCI = true;

  meta = {
    description = "Chisel hardware construction language source and development helpers";
    homepage = "https://github.com/chipsalliance/chisel";
    license = lib.licenses.asl20;
    mainProgram = "chisel-init";
    platforms = lib.platforms.unix;
  };
}
