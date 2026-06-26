# Generic source-distribution builder for PULP Platform (ETH Zurich) RTL packages.
# Usage in pkgs/default.nix:
#   pulp-riscv-dbg0 = callPackage ./pulp {
#     pname   = "riscv-dbg";
#     version = "0.7.0";
#     hash    = "sha256-...";
#   };
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  # Required
  pname,
  version,
  hash,
  rev,
  # Optional overrides
  repo ? pname,
  fetchSubmodules ? false,
  description ? "PULP Platform ${pname} RTL source",
  license ? lib.licenses.asl20,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "pulp-platform";
    inherit
      repo
      rev
      hash
      fetchSubmodules
      ;
  };

  dontConfigure = true;
  dontBuild = true;
  dontPatchShebangs = true;
  dontCheckForBrokenSymlinks = true;

  installPhase = ''
    runHook preInstall

    share="$out/share/${finalAttrs.pname}"
    mkdir -p "$share" "$out/bin"
    cp -R . "$share"

    cat > "$out/bin/${finalAttrs.pname}-path" <<EOF
    #!${stdenvNoCC.shell}
    echo "$share"
    EOF
    chmod +x "$out/bin/${finalAttrs.pname}-path"

    runHook postInstall
  '';

  passthru.nixchipCI = true;

  meta = {
    inherit description license;
    homepage = "https://github.com/pulp-platform/${repo}";
    mainProgram = "${finalAttrs.pname}-path";
    platforms = lib.platforms.unix;
  };
})
