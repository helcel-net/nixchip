# nixpkgs' claude-code (upstream's native binary plus the runtime wrapper)
# re-pointed at the latest release from sources.json, which
# scripts/update-ai-agents.sh refreshes.
{
  lib,
  stdenvNoCC,
  fetchurl,
  claude-code,
}:

let
  sources = lib.importJSON ./sources.json;
  inherit (stdenvNoCC.hostPlatform) system;
  platform =
    {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      x86_64-darwin = "darwin-x64";
      aarch64-darwin = "darwin-arm64";
    }
    .${system};
in
claude-code.overrideAttrs {
  inherit (sources) version;
  src = fetchurl {
    url = "https://downloads.claude.ai/claude-code-releases/${sources.version}/${platform}/claude";
    hash = sources.hashes.${system};
  };
}
