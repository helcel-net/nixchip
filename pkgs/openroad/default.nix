# OpenROAD built from branch HEAD with Bazel. Upstream dropped the CMake
# build after 26Q4 (pkgs/openroad/cmake.nix keeps it for release slots).
#
# Bazel builds hermetically: a statically linked LLVM toolchain and static Qt
# come from the dependency graph, and the result links only against glibc.
# nixpkgs' buildBazelPackage only drives bazel 7, so this owns the two steps:
# a fixed-output `bazel vendor` of every external repository, then an offline
# build against it.
#
# Nix's sandbox has no /lib64 loader, so the dynamically linked interpreters
# Bazel downloads cannot run there. rules_python's standalone CPythons run
# during the dependency fetch itself, so MODULE.bazel is pointed at copies
# patched against nixpkgs' glibc (file:// URLs, which also resolve offline);
# node only runs at build time and is patched in the vendored tree instead.
#
# The update bot only rewrites version/rev/hash. When the module graph
# changes, re-fix depsHash (build once with lib.fakeHash to learn it).
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  bazel_9,
  autoPatchelfHook,
  bash,
  cacert,
  coreutils,
  dbus,
  fontconfig,
  libice,
  libsm,
  libx11,
  libxcb,
  libxcb-cursor,
  libxcb-image,
  libxcb-keysyms,
  libxcb-render-util,
  libxcb-util,
  libxcb-wm,
  libxkbcommon,
  git,
  python3,
  version ? "unstable-2026-11-18",
  rev ? "8c9084f85c0e0ccf9b3daf0f65c66484d82a7695",
  hash ? "sha256-0sozCtRfEvM9gVtmkYeVzcoOutRoKJK1LV/N9GAD7WM=",
  depsHash ? "sha256-jvBFGVRmBmWyLuwhajJWojfHYT0MwcqoLbpNaXZJk5c=",
  ...
}:

let
  # The Qt GUI build. Qt itself is built from source and linked in; the X11 /
  # xcb / fontconfig / dbus / xkbcommon libraries it uses are linked against
  # stubs and resolved at runtime (autoPatchelf points them at nixpkgs).
  # Without -gui it runs headless like the plain //:openroad target.
  target = "//:openroad-qt";

  # rules_python's interpreters (MINOR_MAPPING of the rules_python version in
  # the module graph); hashes from its python/private/runtimes_manifest.txt.
  pbsRelease = "20260414";
  standalonePythons = {
    "3.12.13" = "sha256-zc+HJNRuSFf4217p9CUtwvXaNPeUApTsazEjid0/QeA=";
    "3.13.13" = "sha256-5ew7LFaTIV0VPENKwBjnVRGyxPltK84wRopHfLOonV4=";
  };
  patchedPython =
    pyVersion: sha256:
    stdenv.mkDerivation {
      name = "cpython-${pyVersion}-standalone-nix.tar.gz";
      src = fetchurl {
        url = "https://github.com/astral-sh/python-build-standalone/releases/download/${pbsRelease}/cpython-${pyVersion}+${pbsRelease}-x86_64-unknown-linux-gnu-install_only.tar.gz";
        hash = sha256;
      };
      nativeBuildInputs = [ autoPatchelfHook ];
      # Optional extension modules (tkinter, ...) link libraries nothing here uses.
      autoPatchelfIgnoreMissingDeps = [ "*" ];
      sourceRoot = ".";
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;
      installPhase = ''
        autoPatchelf python
        tar -czf "$out" python
      '';
    };
  # Appended to MODULE.bazel; the `python` extension proxy is declared there.
  pythonOverrides = lib.concatStrings (
    lib.mapAttrsToList (pyVersion: sha256: ''
      cat >> MODULE.bazel <<EOF
      python.single_version_platform_override(
          platform = "x86_64-unknown-linux-gnu",
          python_version = "${pyVersion}",
          urls = ["file://${patchedPython pyVersion sha256}"],
          sha256 = "$(sha256sum ${patchedPython pyVersion sha256} | cut -d" " -f1)",
          strip_prefix = "python",
      )
      EOF
    '') standalonePythons
  );

  src = fetchFromGitHub {
    owner = "The-OpenROAD-Project";
    repo = "OpenROAD";
    fetchSubmodules = true;
    inherit rev hash;
  };

  # nixpkgs' bazel wrapper refuses to run against a different .bazelversion
  # (upstream pins a newer 9.x patch release). Upstream's .bazelrc also points
  # at its remote cache and at caches under $HOME; none exist in the sandbox.
  bazelSetup = ''
    rm -f .bazelversion
    ${pythonOverrides}
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    bazelFlags=(
      --remote_cache=
      --disk_cache=
      --repository_cache="$TMPDIR/repository-cache"
      # Keep fetched repositories as real directories rather than links into
      # a shared contents cache, so they can be vendored and replayed.
      --repo_contents_cache=
      # aspect_tools_telemetry otherwise phones home with module versions.
      --repo_env=DO_NOT_TRACK=1
      # Our edits to fetched repositories (the /usr/bin/env rewrite, patching
      # node) are deliberate; without this bazel re-fetches any repository
      # whose files changed, undoing them (and failing offline).
      --noexperimental_check_external_repository_files
    )

    # Rule sets bake `#!/usr/bin/env` into launchers and templates
    # (rules_python's stub shebang, rules_pkg tools, ...), and the sandbox has
    # no /usr/bin/env. Both derivations rewrite it to a fixed, store-free path
    # in the sandbox build directory, so vendored contents, repository markers
    # and the lockfile all agree, and link that path to the real env.
    if ! mkdir -p /build/.nixchip-bin; then
      echo "openroad: needs the Nix sandbox (build directory /build)" >&2
      exit 1
    fi
    # A wrapper rather than a link: some actions run with a PATH that has no
    # bash or python3, which `env bash` / `env python3` then cannot find.
    cat > /build/.nixchip-bin/env <<EOF
    #!${bash}/bin/bash
    PATH="\''${PATH:+\$PATH:}${lib.makeBinPath [ bash coreutils python3 ]}" exec ${coreutils}/bin/env "\$@"
    EOF
    chmod +x /build/.nixchip-bin/env
    # Likewise for the loader: the hermetic toolchain links everything against
    # /lib64/ld-linux-x86-64.so.2 and bazel runs the tools it builds.
    ln -sf ${stdenv.cc.bintools.dynamicLinker} /build/.nixchip-bin/ld-linux-x86-64.so.2
    rewriteEnv() {
      { grep -rlIFZ '#!/usr/bin/env' "$@" || true; } \
        | xargs -0 -r sed -i 's|#!/usr/bin/env|#!/build/.nixchip-bin/env|g'
    }
    rewriteEnv .
  '';

  deps = stdenv.mkDerivation {
    name = "openroad-${version}-bazel-deps";
    inherit src;

    nativeBuildInputs = [
      bazel_9
      cacert
      git
      python3
    ];

    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      ${bazelSetup}
      # `bazel vendor //:openroad` analyses no targets here, and vendoring the
      # whole module graph fetches (and fails on) repositories for other
      # platforms and Python versions. Analysis fetches exactly what
      # //:openroad needs; vendor those repositories by name.
      analyse() {
        bazel --output_user_root="$TMPDIR/bazel" build "''${bazelFlags[@]}" \
          --nobuild ${target}
        external="$(bazel --output_user_root="$TMPDIR/bazel" info "''${bazelFlags[@]}" output_base)/external"
        repos=()
        repoDirs=()
        for dir in "$external"/*/; do
          name=$(basename "$dir")
          case "$name" in
            # Host-probing repositories are regenerated by every build; the
            # patched interpreters reference the store, which a fixed-output
            # path may not, and are re-created from their file:// URLs.
            _main | bazel_tools | *local_config* | *host_platform* \
              | rules_python++python+python_3_*) ;;
            *)
              repos+=("--repo=@@$name")
              repoDirs+=("$dir")
              ;;
          esac
        done
      }
      # A rule set's .bzl defines the repositories its rules create, so
      # rewriting it invalidates those; re-analyse until no fetched .bzl needs
      # rewriting. Other files (scripts and templates inside fetched archives)
      # do not affect repository definitions: rewrite them once, after the
      # final analysis, so nothing re-fetches over the edit.
      analyse
      for pass in 1 2 3 4; do
        mapfile -t bzls < <(find "''${repoDirs[@]}" -name '*.bzl' -type f \
          -exec grep -lIF '#!/usr/bin/env' {} +)
        if [ "''${#bzls[@]}" = 0 ]; then
          break
        fi
        if [ "$pass" = 4 ]; then
          echo "openroad: .bzl /usr/bin/env rewrite did not converge:" >&2
          printf '%s\n' "''${bzls[@]}" | head -20 >&2
          exit 1
        fi
        sed -i 's|#!/usr/bin/env|#!/build/.nixchip-bin/env|g' "''${bzls[@]}"
        analyse
      done
      rewriteEnv "''${repoDirs[@]}"
      # Point the hermetic toolchain's links at that fixed loader path.
      linuxArgs="$external/llvm+/toolchain/args/linux/BUILD.bazel"
      grep -qF '"-Wl,-z,relro,-z,now",' "$linuxArgs"
      sed -i 's|"-Wl,-z,relro,-z,now",|&\n        "-Wl,--dynamic-linker=/build/.nixchip-bin/ld-linux-x86-64.so.2",|' "$linuxArgs"
      # The toolchain's own host tools (module-map-generator, ...) link through
      # the runtime-stage args, which do not include the linux defaults.
      runtimeArgs="$external/llvm+/toolchain/runtimes/args/BUILD.bazel"
      [ "$(grep -c '"//toolchain:runtimes_stage1_hosted": \[' "$runtimeArgs")" = 1 ]
      sed -i '/"\/\/toolchain:runtimes_stage1_hosted": \[/a\            "-Wl,--dynamic-linker=/build/.nixchip-bin/ld-linux-x86-64.so.2",' "$runtimeArgs"
      echo "vendoring ''${#repos[@]} repositories"
      bazel --output_user_root="$TMPDIR/bazel" vendor "''${bazelFlags[@]}" \
        --vendor_dir="$out" "''${repos[@]}"
      bazel --output_user_root="$TMPDIR/bazel" shutdown
      # Upstream's lockfile is written by a newer bazel and resolves slightly
      # differently here; a stale lockfile makes the offline build re-resolve
      # the module graph against the network. Ship the one this bazel wrote,
      # with store paths (the interpreter file:// URLs) as a placeholder.
      mkdir -p "$out/.nixchip"
      sed "s|$NIX_STORE/|@NIX_STORE@/|g" MODULE.bazel.lock > "$out/.nixchip/MODULE.bazel.lock"
      if leaks=$(grep -rlF "$NIX_STORE/" "$out"); then
        echo "vendored repositories reference the store:" >&2
        echo "$leaks" | head -20 >&2
        exit 1
      fi
      runHook postBuild
    '';
    dontInstall = true;
    dontFixup = true;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = depsHash;
  };
in
stdenv.mkDerivation {
  pname = "openroad";
  inherit version src;

  nativeBuildInputs = [
    bazel_9
    autoPatchelfHook
    git
    python3
  ];

  # Runtime libraries of the GUI, for autoPatchelf.
  buildInputs = [
    (lib.getLib dbus)
    fontconfig
    libice
    libsm
    libx11
    libxcb
    libxcb-cursor
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-util
    libxcb-wm
    libxkbcommon
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    ${bazelSetup}
    # Prebuilt tools in the vendored graph are static, except node, which
    # needs a loader; patch a writable copy before bazel executes it.
    cp -r ${deps} "$TMPDIR/vendor"
    chmod -R u+w "$TMPDIR/vendor"
    autoPatchelf "$TMPDIR/vendor"
    sed "s|@NIX_STORE@/|$NIX_STORE/|g" "$TMPDIR/vendor/.nixchip/MODULE.bazel.lock" > MODULE.bazel.lock

    # Files copied out of the store carry 1970 mtimes, which zip (used to
    # package the Tcl resources) rejects as predating 1980.
    find . "$TMPDIR/vendor" -exec touch -h -d @315619200 {} +

    # Actions must only see declared inputs (hermetic glibc ships #error
    # template headers it excludes); processwrapper-sandbox isolates with
    # symlink trees and needs no namespaces, unlike linux-sandbox.
    export OPENROAD_VERSION=${lib.escapeShellArg version}
    bazel --output_user_root="$TMPDIR/bazel" build "''${bazelFlags[@]}" \
      --vendor_dir="$TMPDIR/vendor" \
      --lockfile_mode=error \
      --verbose_failures \
      --spawn_strategy=processwrapper-sandbox \
      --jobs="$NIX_BUILD_CORES" \
      --stamp \
      ${target}
    install -Dm755 "$(readlink -f bazel-bin/openroad-qt)" "$TMPDIR/openroad"
    bazel --output_user_root="$TMPDIR/bazel" shutdown
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 "$TMPDIR/openroad" "$out/bin/openroad"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/openroad" -version
    runHook postInstallCheck
  '';

  passthru = {
    inherit deps;
    # Refreshed by scripts/update-packages.sh after every rev bump.
    nixchipDerivedHashes = [ "depsHash:deps" ];
    nixchipUpdate = true;
    nixchipCI = true;
  };

  meta = {
    description = "Integrated chip physical design tool, from RTL to GDSII";
    homepage = "https://theopenroadproject.org";
    license = lib.licenses.bsd3;
    mainProgram = "openroad";
    platforms = [ "x86_64-linux" ];
  };
}
