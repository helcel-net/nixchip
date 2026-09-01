# Verible built from branch HEAD with bazel 8 and a pinned bazel-central-
# registry snapshot. nixpkgs' verible (the verible0 slot) drives bazel 7
# against an older BCR snapshot baked into an internal let-binding that
# .override cannot reach; verible revs past 083a3689 need bazel-8-era modules
# (rules_cc 0.2.16, rules_shell 0.8.0, ...), so this package owns the whole
# bazel setup instead of overriding nixpkgs'. (HEAD turns out to build with
# bazel 7 once the registry is fresh; bazel_8 lacks the enableNixHacks arg
# buildBazelPackage needs, so stay on 7 until nixpkgs supports 8 there.)
#
# The update bot only rewrites version/rev/hash. When a bump fails during the
# dependency fetch, refresh registryRev/registryHash to a current BCR commit;
# when the resolved module set changes, re-fix depsHash (build once with
# lib.fakeHash to learn the new value).
{
  lib,
  buildBazelPackage,
  fetchFromGitHub,
  bazel_7,
  jdk,
  bison,
  flex,
  python3,
  version ? "unstable-2026-09-01",
  rev ? "fdbac312ba11d6a75977443b48f4b90780da9d78",
  hash ? "sha256-YTy3fC2HC8gr4A2nxR+ILfTDSKHnmg26MuW4jgP7QK0=",
  # git-describe string embedded in --version output (last tag + commits since);
  # not bot-maintained, so it can lag behind rev -- cosmetic only.
  gitVersion ? "v0.0-4157-gfdbac312",
  registryRev ? "222e49312e3fcc884991af688e0eec6f67a1e919",
  registryHash ? "sha256-s2EceFCz3/XblRPEcSxzMpXyQWtaOlcy143RbWqwjYw=",
  depsHash ? "sha256-RXji3oV9ccUfje8+i73w7dox9e4wZH3KADJ+YecFgL4=",
}:

let
  registry = fetchFromGitHub {
    owner = "bazelbuild";
    repo = "bazel-central-registry";
    rev = registryRev;
    hash = registryHash;
  };
in
buildBazelPackage {
  pname = "verible";
  inherit version;

  # Read by bazel/build-version.sh (the workspace status command) when .git is
  # absent, to embed a build string into the tools' --version output.
  env = {
    GIT_DATE = lib.removePrefix "unstable-" version;
    GIT_VERSION = gitVersion;
  };

  src = fetchFromGitHub {
    owner = "chipsalliance";
    repo = "verible";
    inherit rev hash;
  };

  bazel = bazel_7;
  bazelFlags = [
    "--//bazel:use_local_flex_bison"
    "--registry"
    "file://${registry}"
  ];

  fetchAttrs = {
    # local_config_shell captures host paths and would make the vendored deps
    # nondeterministic. Bazel 8 renamed external directories from ~ to +
    # separators; keep both spellings so this survives either bazel.
    preInstall = ''
      rm -rf \
        "$bazelOut"/external/rules_shell~~sh_configure~local_config_shell \
        "$bazelOut"/external/rules_shell++sh_configure+local_config_shell
    '';
    hash = depsHash;
  };

  nativeBuildInputs = [
    jdk # bazel uses it
    bison # local flex/bison: the WORKSPACE sources fail against newer glibc
    flex
    python3
  ];

  # Directories instead of nixpkgs' explicit file list: scripts move between
  # HEAD revisions (build-version.py became build-version.sh).
  postPatch = ''
    patchShebangs \
      .github/bin/simple-install.sh \
      bazel \
      kythe-browse.sh \
      verible/common/lsp \
      verible/common/tools \
      verible/verilog/tools
  '';

  removeRulesCC = false;
  bazelTargets = [ ":install-binaries" ];
  bazelBuildFlags = [ "-c opt" ];

  doCheck = true;
  bazelTestTargets = [ "//..." ];
  bazelTestFlags = [ "-c opt" ];

  buildAttrs = {
    installPhase = ''
      mkdir -p "$out/bin"
      .github/bin/simple-install.sh "$out/bin"
    '';
  };

  passthru = {
    nixchipCI = true;
    nixchipUpdate = true;
  };

  meta = {
    description = "Suite of SystemVerilog developer tools: style-linter, indexer, formatter, and language server";
    homepage = "https://github.com/chipsalliance/verible";
    license = lib.licenses.asl20;
    mainProgram = "verible-verilog-lint";
    platforms = lib.platforms.linux;
  };
}
