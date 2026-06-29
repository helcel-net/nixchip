{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  version ? "unstable-2020-09-14",
  rev ? "675e97b0958f3b142594c3d0cec3e79114e751a3",
  hash ? "sha256-A7t1Dd+qZXq/dgzY5b7EaD4wiyLy9wWXqWwk/LRk/80=",
}:

stdenv.mkDerivation {
  pname = "flexfloat";
  inherit version;

  src = fetchFromGitHub {
    owner = "oprecomp";
    repo = "flexfloat";
    inherit rev hash;
  };

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    "-DBUILD_TESTS=OFF"
    "-DBUILD_EXAMPLES=OFF"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/include $out/src $out/lib
    cp -r ../include/* $out/include/
    cp -r ../src/* $out/src/
    cp libflexfloat.a $out/lib/libflexfloat.a

    runHook postInstall
  '';

  meta = {
    description = "C library for emulating reduced-precision floating-point formats";
    homepage = "https://github.com/oprecomp/flexfloat";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
}
