{
  fetchFromGitHub,
  klayout,
  version ? "0.30.8",
  hash ? "sha256-RjMH6hrc0jyCLgG1D6cztBp5Fb3W5HgTxVTfI2bxgCs=",
}:

klayout.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "KLayout";
    repo = "klayout";
    rev = "v${version}";
    inherit hash;
  };
})
