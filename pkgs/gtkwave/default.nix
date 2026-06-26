{
  lib,
  stdenv,
  fetchFromGitHub,
  desktop-file-utils,
  flex,
  gperf,
  meson,
  ninja,
  pkg-config,
  wrapGAppsHook4,
  glib,
  gtk3,
  gtk4,
  json-glib,
  zlib,
  bzip2,
  nix-update-script,
  version ? "unstable-2026-06-26",
  rev ? "7d7b4db9e2f5485afe2aeeab0ad112f5b6a9b94b",
  hash ? "sha256-lEKW/OHk9xTqvf7UIcbZ3/toE6hWmed4dR/Ia21XY6I=",
  libfstRev ? "74301348450701727776c1a0522a3f512738e9ae",
  libfstHash ? "sha256-Fm3sfuNvnN5J3VGgptI9TacyJl175MtkDFqQ3A/iegQ=",
  ...
}:

let
  libfstSrc = fetchFromGitHub {
    owner = "gtkwave";
    repo = "libfst";
    rev = libfstRev;
    hash = libfstHash;
  };
in
stdenv.mkDerivation {
  pname = "gtkwave";
  inherit version;

  src = fetchFromGitHub {
    owner = "gtkwave";
    repo = "gtkwave";
    inherit rev hash;
  };

  postPatch = ''
    cp -r --no-preserve=mode,ownership ${libfstSrc} subprojects/libfst
  '';

  nativeBuildInputs = [
    desktop-file-utils
    flex
    gperf
    meson
    ninja
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = [
    glib
    gtk3
    gtk4
    json-glib
    zlib
    bzip2
  ];

  mesonFlags = [
    "-Dtests=false"
    "-Dupdate_mime_database=false"
    "-Djudy=disabled"
    "-Dlibgtkwave_docs=false"
    "-Dintrospection=false"
    "-Dset_rpath=disabled"
  ];

  passthru = {
    updateScript = nix-update-script {
      attrPath = "gtkwave";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };

  meta = {
    description = "Waveform viewer for Verilog, VHDL, and other simulation dump formats";
    homepage = "https://gtkwave.sourceforge.net";
    license = lib.licenses.gpl2Plus;
    mainProgram = "gtkwave";
    platforms = lib.platforms.unix;
  };
}
