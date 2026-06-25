{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  nix-update-script,
  version,
  rev,
  hash,
  # 2.x compiles with C++14; 3.x requires C++17 due to
  # https://github.com/accellera-official/systemc/issues/21
  cxxStandard ? if lib.versionAtLeast version "3" then "17" else "14",
}:

stdenv.mkDerivation {
  pname = "systemc";
  inherit version;

  src = fetchFromGitHub {
    owner = "accellera-official";
    repo = "systemc";
    inherit rev hash;
  };

  postPatch = lib.optionalString (lib.versionOlder version "3") ''
    find . \( -name CMakeLists.txt -o -name '*.cmake' \) -exec sed -i \
      's/cmake_minimum_required\s*(VERSION [0-2]\.[0-9][^)]*)/cmake_minimum_required (VERSION 3.5)/g;
       s/cmake_minimum_required\s*(VERSION 3\.[0-4][^)]*)/cmake_minimum_required (VERSION 3.5)/g' \
      {} +
  '';

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [ "-DCMAKE_CXX_STANDARD=${cxxStandard}" ];

  doCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  passthru.updateScript = nix-update-script {
    attrPath = "systemc";
    extraArgs = [ "--version=branch" ];
  };
  passthru.nixchipUpdate = true;
  passthru.nixchipCI = true;

  meta = {
    description = "Language for system-level design, modeling and verification";
    homepage = "https://systemc.org/";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
}
