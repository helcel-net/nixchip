{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  version ? "0.0.0-10898-g8ddae8bf4",
  hash ? "sha256-BVuCiU90fl7KK7O6IQvo9NSCe1fa2yhhk1vUroCeTKM=",
}:

# Upstream's prebuilt release: building XLS from source means Bazel plus its
# own LLVM toolchain.
stdenv.mkDerivation {
  pname = "xls";
  inherit version;

  src = fetchurl {
    url = "https://github.com/google/xls/releases/download/v${version}/xls-v${version}-linux-x64.tar.gz";
    inherit hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/xls $out/share/xls $out/bin
    # The release marks its text files executable too.
    for f in *; do
      if isELF "$f"; then cp "$f" $out/libexec/xls/; fi
    done
    cp -r xls/dslx $out/share/xls/
    cp LICENSE THIRD_PARTY_NOTICES.txt $out/share/xls/

    # The DSLX stdlib defaults to xls/dslx/stdlib relative to the working
    # directory; point the tools that import it at the installed copy.
    stdlib=$out/share/xls/dslx/stdlib
    for tool in $out/libexec/xls/*; do
      name=$(basename "$tool")
      case "$name" in
        interpreter_main | ir_converter_main | parse_and_typecheck_dslx_main | prove_quickcheck_main)
          makeWrapper "$tool" $out/bin/$name --add-flags "--dslx_stdlib_path=$stdlib" ;;
        dslx_ls)
          makeWrapper "$tool" $out/bin/$name --add-flags "--stdlib_path=$stdlib" ;;
        *)
          ln -s "$tool" $out/bin/$name ;;
      esac
    done

    runHook postInstall
  '';

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
    # Releases are tagged v0.0.0-<commit count>-g<sha>.
    nixchipUpdateFlags = [ "--version-regex=^v(0\\.0\\.0-[0-9]+-g[0-9a-f]+)$" ];
  };

  meta = {
    description = "Google XLS high-level synthesis toolchain and the DSLX hardware description language";
    homepage = "https://google.github.io/xls/";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
