# Upstream's prebuilt opencode release (a bun-compiled binary), wrapped like
# nixpkgs' source build. sources.json is refreshed by
# scripts/update-ai-agents.sh.
{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  installShellFiles,
  makeBinaryWrapper,
  unzip,
  ripgrep,
  sysctl,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  sources = lib.importJSON ./sources.json;
  inherit (stdenvNoCC.hostPlatform) system;
  asset =
    {
      x86_64-linux = "linux-x64.tar.gz";
      aarch64-linux = "linux-arm64.tar.gz";
      x86_64-darwin = "darwin-x64.zip";
      aarch64-darwin = "darwin-arm64.zip";
    }
    .${system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${finalAttrs.version}/opencode-${asset}";
    hash = sources.hashes.${system};
  };
  sourceRoot = ".";

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
    writableTmpDirAsHomeHook
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isElf [ autoPatchelfHook ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [ unzip ];

  # Stripping drops the embedded bundle and leaves the bare bun runtime.
  dontStrip = true;

  env.OPENCODE_DISABLE_MODELS_FETCH = "true";

  installPhase = ''
    runHook preInstall

    # At startup opencode creates ./opencode, so a leftover copy of the binary
    # in the build dir would collide with it.
    install -Dm755 -t $out/bin opencode
    rm opencode
  ''
  # Patch now rather than in fixupPhase: completions below run the binary.
  + lib.optionalString stdenvNoCC.hostPlatform.isElf ''
    autoPatchelf $out/bin
  ''
  + lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    installShellCompletion --cmd opencode \
      --bash <($out/bin/opencode completion) \
      --zsh <(SHELL=/bin/zsh $out/bin/opencode completion)
  ''
  + ''
    wrapProgram $out/bin/opencode \
      --prefix PATH : ${
        lib.makeBinPath ([ ripgrep ] ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [ sysctl ])
      } \
      --set OPENCODE_DISABLE_AUTOUPDATE true

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckKeepEnvironment = [
    "HOME"
    "OPENCODE_DISABLE_MODELS_FETCH"
  ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    changelog = "https://github.com/anomalyco/opencode/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames sources.hashes;
    mainProgram = "opencode";
  };
})
