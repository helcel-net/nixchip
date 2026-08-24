# stream-dse — multi-core / layer-fused accelerator DSE (KU Leuven MICAS, the
# same group as zigzag-dse, and built directly on top of it). Not in nixpkgs;
# built from the real PyPI wheel. Two satellite deps are built here as internal
# derivations rather than exposed attrs:
#  - xdsl: not packaged in nixpkgs at all.
#  - ortools from its PyPI wheel: nixpkgs' python ortools builds from source
#    against a protobuf older than stream-dse's shared >=6.33.1 floor. The
#    wheel is interpreter-specific (cp3XX), so it is selected by python
#    version; extend `ortoolsWheels` when the default python moves.
# The onnx that propagates through zigzag-dse is the PyPI-wheel onnx (see
# pkgs/zigzag-dse): mixing nixpkgs' onnx with ortools' vendored libprotobuf
# SIGSEGVs, so consumers must not add nixpkgs' onnx alongside this package.
{
  lib,
  buildPythonPackage,
  fetchurl,
  python,
  zigzag-dse,
  cerberus,
  pydantic,
  pydot,
  immutabledict,
  ordered-set,
  typing-extensions,
  absl-py,
  numpy,
  pandas,
  protobuf,
  version ? "1.13.11",
  hash ? "sha256-U76vgNYVrKBG1Oqw1eNOfT+4Smk1eNs2ST0ZkD6LblM=",
}:

let
  ortoolsWheels = {
    "3.12" = {
      url = "https://files.pythonhosted.org/packages/49/0f/6d6d722102a0ceccf4a5038e2bc91d023da84a6dba98482a4634df3d27ab/ortools-9.15.6755-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256-Azg2wOszvHJpeimeDK7bsl/J0c7gsTgy1pyzBAX1ez4=";
    };
    "3.13" = {
      url = "https://files.pythonhosted.org/packages/08/b9/28d5efb832190b6edfccc5a703e88e64779c1eda34a42ea96d03307236c0/ortools-9.15.6755-cp313-cp313-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256-69WuoAN046rXp43lkFispehxomo8OFzQhg7x1oXQPJo=";
    };
  };
  ortoolsWheel =
    ortoolsWheels.${python.pythonVersion}
      or (throw "stream-dse: no ortools wheel pinned for python ${python.pythonVersion}; add it to ortoolsWheels in pkgs/stream-dse");

  ortools = buildPythonPackage {
    pname = "ortools";
    version = "9.15.6755";
    format = "wheel";
    src = fetchurl { inherit (ortoolsWheel) url hash; };
    # nixpkgs' shared protobuf is reused (the wheel's own pin is conservative);
    # a dedicated pinned protobuf would collide with onnx's in one closure.
    pythonRelaxDeps = [ "protobuf" ];
    propagatedBuildInputs = [
      absl-py
      numpy
      pandas
      protobuf
      typing-extensions
      immutabledict
    ];
    doCheck = false;
  };

  xdsl = buildPythonPackage {
    pname = "xdsl";
    version = "0.29.1";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/81/16/94f64780274219c5662faca67c1656ca561e7bd1b2512d72e17577bad629/xdsl-0.29.1-py3-none-any.whl";
      hash = "sha256-HcgSl6dZZ6BzEU9qGBlPcwIWJ3TfhRmEyZMlbveL73s=";
    };
    # nixpkgs' typing-extensions/immutabledict are past xdsl's stated upper
    # pins; both are thin compatibility/data-structure shims.
    pythonRelaxDeps = [
      "typing-extensions"
      "immutabledict"
    ];
    propagatedBuildInputs = [
      immutabledict
      ordered-set
      typing-extensions
    ];
    doCheck = false;
  };
in
buildPythonPackage {
  pname = "stream-dse";
  inherit version;
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/3e/a8/b1da12fbe6ade0546b6894827baa2363fbbe0e4574e4d79f07b08a8a82da/stream_dse-${version}-py3-none-any.whl";
    inherit hash;
  };

  # This environment's pydantic can be newer than stream-dse's upper pin.
  pythonRelaxDeps = [ "pydantic" ];
  propagatedBuildInputs = [
    zigzag-dse
    cerberus
    ortools
    pydantic
    pydot
    xdsl
  ];

  doCheck = false;
  pythonImportsCheck = [ "stream" ];

  passthru.nixchipCI = true;
  # Release-pinned, but still built and cached on every main push — the point
  # of packaging it is that downstream never builds it.
  passthru.nixchipCIDefault = true;

  meta = {
    description = "Stream multi-core / layer-fused accelerator DSE framework";
    homepage = "https://github.com/KULeuven-MICAS/stream";
    license = lib.licenses.mit;
  };
}
