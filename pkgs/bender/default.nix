{
  lib,
  rustPlatform,
  fetchFromGitHub,
  gitMinimal,
  nix-update-script,
  version ? "0.32.0",
  hash ? "sha256-Pyx68NTlCNTGKXdEGG9YML5E+vJlLHlPQjjbSV2uOsE=",
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "bender";
  inherit version;

  src = fetchFromGitHub {
    owner = "pulp-platform";
    repo = "bender";
    tag = "v${finalAttrs.version}";
    inherit hash;
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeCheckInputs = [ gitMinimal ];
  doCheck = false;

  passthru = {
    updateScript = nix-update-script { };
    nixchipUpdate = true;
    nixchipCI = true;
  };

  meta = {
    description = "Dependency management tool for hardware projects";
    homepage = "https://github.com/pulp-platform/bender";
    license = with lib.licenses; [ asl20 mit ];
    mainProgram = "bender";
    platforms = lib.platforms.all;
  };
})
