{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  patchelf,
  # Pinned to v2.0a (the direct parent of the 2026-06-27 "Ramulator 2.1"
  # restructure). Newer commits drop the standalone `ramulator2` executable
  # and the YAML example configs in favour of a Python-bindings library.
  version ? "unstable-2026-03-25",
  rev ? "be93be78055d922aa1d4d33e15bcc8f2b0c61a9d",
  hash ? "sha256-ypz6Acpb/9nC/PD6d7n9vM0etcT1hteVbwaoR9wJoOA=",
}:

let
  # Ramulator 2's CMakeLists downloads its dependencies at configure time via
  # FetchContent, which cannot work in the network-less Nix sandbox. Instead of
  # patching the build to use nixpkgs' (newer, potentially incompatible)
  # yaml-cpp/spdlog/argparse, we pre-fetch the exact tags upstream pins and
  # hand them to CMake with FETCHCONTENT_FULLY_DISCONNECTED +
  # FETCHCONTENT_SOURCE_DIR_<NAME>. This keeps the build byte-identical to
  # upstream's and is robust against nixpkgs dependency bumps.
  yaml-cpp-src = fetchFromGitHub {
    owner = "jbeder";
    repo = "yaml-cpp";
    rev = "yaml-cpp-0.7.0";
    hash = "sha256-2tFWccifn0c2lU/U1WNg2FHrBohjx8CXMllPJCevaNk=";
  };

  spdlog-src = fetchFromGitHub {
    owner = "gabime";
    repo = "spdlog";
    rev = "v1.11.0";
    hash = "sha256-kA2MAb4/EygjwiLEjF9EA7k8Tk//nwcKB1+HlzELakQ=";
  };

  argparse-src = fetchFromGitHub {
    owner = "p-ranav";
    repo = "argparse";
    rev = "v2.9";
    hash = "sha256-vbf4kePi5gfg9ub4aP1cCK1jtiA65bUS9+5Ghgvxt/E=";
  };
in

stdenv.mkDerivation {
  pname = "ramulator2";
  inherit version;

  src = fetchFromGitHub {
    owner = "CMU-SAFARI";
    repo = "ramulator2";
    inherit rev hash;
  };

  nativeBuildInputs = [
    cmake
    patchelf
  ];

  cmakeFlags = [
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DFETCHCONTENT_SOURCE_DIR_YAML-CPP=${yaml-cpp-src}"
    "-DFETCHCONTENT_SOURCE_DIR_SPDLOG=${spdlog-src}"
    "-DFETCHCONTENT_SOURCE_DIR_ARGPARSE=${argparse-src}"
    # yaml-cpp 0.7.0 declares cmake_minimum_required(VERSION 3.4)
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  ];

  # Upstream provides no install target: the executable lands in the build
  # dir and libramulator.so in the source dir (LIBRARY_OUTPUT_DIRECTORY).
  installPhase = ''
    runHook preInstall

    install -Dm755 ramulator2 "$out/bin/ramulator2"
    install -Dm644 ../libramulator.so "$out/lib/libramulator.so"
    patchelf --set-rpath "$out/lib:${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" "$out/bin/ramulator2"
    mkdir -p "$out/share/ramulator2"
    # The example configs reference the traces by relative path, so ship them
    # side by side.
    install -Dm644 -t "$out/share/ramulator2" ../example_config*.yaml ../example_*.trace
    install -Dm644 ../README.md "$out/share/doc/ramulator2/README.md"

    runHook postInstall
  '';

  passthru.nixchipCI = true;

  meta = {
    description = "Modern, modular, and extensible cycle-accurate DRAM simulator";
    homepage = "https://github.com/CMU-SAFARI/ramulator2";
    license = lib.licenses.mit;
    mainProgram = "ramulator2";
    platforms = lib.platforms.unix;
  };
}
