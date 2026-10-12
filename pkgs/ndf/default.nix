{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  git,
  version ? "unstable-2026-08-11",
  rev ? "5e3e6b5f09e06b09aaf52844c4b37e38362ac097",
  hash ? "sha256-IIWM8RnPGnRsXeCaqbUV4jtmu+c5eSdT4M/OdpfVhCw=",
  cargoHash ? "sha256-udLmIYZ+Zb+YrkUpIuApDHtTP/Z9AsLsIW35z7uj5wc=",
}:

rustPlatform.buildRustPackage {
  pname = "ndf";
  inherit version cargoHash;

  src = fetchFromGitHub {
    owner = "PTO-ISA";
    repo = "normative_language";
    inherit rev hash;
  };

  cargoBuildFlags = [
    "-p"
    "ndf-cli"
  ];

  nativeBuildInputs = [ makeWrapper ];

  # ndf shells out to git to verify pinned dependency checkouts; the tests
  # build throwaway repositories with it.
  nativeCheckInputs = [ git ];

  postInstall = ''
    wrapProgram $out/bin/ndf --prefix PATH : ${lib.makeBinPath [ git ]}
  '';

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = {
    description = "NDF knowledge compiler for normative engineering documents (PTO spec tooling)";
    homepage = "https://github.com/PTO-ISA/normative_language";
    license = lib.licenses.asl20;
    mainProgram = "ndf";
    platforms = lib.platforms.unix;
  };
}
