# zigzag-dse — hardware-accelerator design-space exploration (KU Leuven MICAS).
# Not in nixpkgs; built from the real PyPI wheel. Two satellite deps are built
# here as internal derivations rather than exposed attrs:
#  - multiprocessing_on_dill: zigzag's only non-nixpkgs runtime dep.
#  - onnx from its own PyPI wheel, shadowing nixpkgs' onnx: the nixpkgs build
#    links libprotobuf by SONAME, and OR-Tools' wheel (see stream-dse) vendors
#    a different one; both loaded together register overlapping descriptors in
#    protobuf's global registry and SIGSEGV. ONNX's own abi3 wheel avoids it,
#    and propagates from here so consumers get exactly one onnx.
{
  lib,
  buildPythonPackage,
  fetchurl,
  numpy,
  networkx,
  sympy,
  matplotlib,
  tqdm,
  pyyaml,
  cerberus,
  seaborn,
  typeguard,
  protobuf,
  typing-extensions,
  ml-dtypes,
  dill,
  version ? "3.8.5",
  hash ? "sha256-fgbAt1pyDnolLLiwghUDrUJdH+VYx4kWXSBZr897J+A=",
}:

let
  multiprocessing-on-dill = buildPythonPackage {
    pname = "multiprocessing_on_dill";
    version = "3.5.0a4";
    format = "setuptools";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/86/4d/4b135e2e5cd0194eb29f2ed36e9a77a07596787a9a8ac2279bd4445398f2/multiprocessing_on_dill-3.5.0a4.tar.gz";
      hash = "sha256-1tUMMA/0vUCLtx63hyXmAjEDnumz0Nm7dpe50OFQRec=";
    };
    propagatedBuildInputs = [ dill ];
    doCheck = false;
  };

  # cp312-abi3: valid for CPython >= 3.12, so it survives interpreter bumps.
  onnx-wheel = buildPythonPackage {
    pname = "onnx";
    version = "1.21.0";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/a7/00/4823f06357892d1e60d6f34e7299d2ba4ed2108c487cc394f7ce85a3ff14/onnx-1.21.0-cp312-abi3-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256-qSYb1YD7hUjJw3s8Z1A4frjyHqQ8Y4gNN7LGIuFoQoU=";
    };
    propagatedBuildInputs = [
      numpy
      protobuf
      typing-extensions
      ml-dtypes
    ];
    doCheck = false;
  };
in
buildPythonPackage {
  pname = "zigzag-dse";
  inherit version;
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/71/13/2c0799ca0c2ae83a49cf770ebe95ab4eb93db8de148b7977eb3c8753a38d/zigzag_dse-${version}-py3-none-any.whl";
    inherit hash;
  };

  propagatedBuildInputs = [
    numpy
    networkx
    sympy
    matplotlib
    onnx-wheel
    tqdm
    multiprocessing-on-dill
    pyyaml
    cerberus
    seaborn
    typeguard
  ];

  doCheck = false;
  pythonImportsCheck = [ "zigzag" ];

  passthru = {
    nixchipCI = true;
    # For consumers (stream-dse) that must share the exact same onnx.
    inherit onnx-wheel;
  };

  meta = {
    description = "ZigZag hardware-accelerator design-space exploration framework";
    homepage = "https://github.com/KULeuven-MICAS/zigzag";
    license = lib.licenses.mit;
  };
}
