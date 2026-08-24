# CHIA (ucb-bar/chia) — agentic hardware-design loops. Not on PyPI; built from
# a pinned commit. Its exact version pins are relaxed against nixpkgs'
# ray/pydantic/fastapi/pytest (newer here) and mcp (1.27.0 here vs CHIA's
# ==1.27.1 patch pin) — compatibility verified downstream, not assumed.
{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  wheel,
  google-genai,
  ray,
  mcp,
  pydantic,
  fastapi,
  pyyaml,
  pytest,
  graphviz,
  boto3,
  google-cloud-compute,
  requests,
  version ? "0.1.0",
  rev ? "098764c04c1260ee83b324153539bec6febab684",
  hash ? "sha256-qs73CL8a0SvvER1BUe5dIr86a5l3cuJf6gvaOlM6ECg=",
}:

buildPythonPackage {
  # Upstream renamed the *distribution* to "chialoops" ("chia" is taken on
  # PyPI); the import package and console script are still `chia`. pname must
  # match the wheel's METADATA Name or pythonMetadataCheckPhase fails, and
  # version must exactly match upstream's own pyproject.toml version — the
  # pinned commit is what's actually reproducible, via `rev`.
  pname = "chialoops";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "ucb-bar";
    repo = "chia";
    inherit rev hash;
  };

  build-system = [
    setuptools
    wheel
  ];

  pythonRelaxDeps = [
    "ray"
    "pydantic"
    "fastapi"
    "pytest"
    "mcp"
  ];

  # ray's [default] extras propagate too (ray serve/dashboard at runtime), so
  # consumers get a complete CHIA environment from this one attr.
  propagatedBuildInputs = [
    google-genai
    ray
    mcp
    pydantic
    fastapi
    pyyaml
    pytest
    graphviz
    boto3
    google-cloud-compute
    requests
  ]
  ++ ray.optional-dependencies.default;

  # fetchFromGitHub leaves the examples/ submodules empty, and the test suite
  # needs docker/cluster infrastructure the sandbox has no way to provide.
  doCheck = false;
  pythonImportsCheck = [ "chia" ];

  passthru.nixchipCI = true;
  # Release-pinned, but still built and cached on every main push — the point
  # of packaging it is that downstream never builds it.
  passthru.nixchipCIDefault = true;

  meta = {
    description = "CHIA agentic hardware-design loops (UC Berkeley)";
    homepage = "https://github.com/ucb-bar/chia";
    license = lib.licenses.bsd3;
  };
}
