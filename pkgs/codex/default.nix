# Upstream's prebuilt codex release (static musl on Linux), wrapped like
# nixpkgs' source build. sources.json is refreshed by
# scripts/update-ai-agents.sh.
{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  makeBinaryWrapper,
  ripgrep,
  bubblewrap,
  versionCheckHook,
}:

let
  sources = lib.importJSON ./sources.json;
  inherit (stdenvNoCC.hostPlatform) system;
  target =
    {
      x86_64-linux = "x86_64-unknown-linux-musl";
      aarch64-linux = "aarch64-unknown-linux-musl";
      x86_64-darwin = "x86_64-apple-darwin";
      aarch64-darwin = "aarch64-apple-darwin";
    }
    .${system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codex";
  inherit (sources) version;

  # codex, and the code-mode host it runs its tools in (0.163+: a release file of
  # its own; Codex looks for it beside itself, and code-mode-only models have no
  # other tool).
  srcs = [
    (fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-${target}.tar.gz";
      hash = sources.hashes.${system};
    })
    (fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-code-mode-host-${target}.tar.gz";
      hash = sources.hostHashes.${system};
    })
  ];
  sourceRoot = ".";

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
  ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 codex-${target} $out/bin/codex
    install -Dm755 codex-code-mode-host-${target} $out/bin/codex-code-mode-host
  ''
  + lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)
  ''
  + ''
    wrapProgram $out/bin/codex --prefix PATH : ${
      lib.makeBinPath ([ ripgrep ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ bubblewrap ])
    }

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames sources.hashes;
    mainProgram = "codex";
  };
})
