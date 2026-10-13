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
  version ? "unstable-2026-10-13",
  rev ? "f6d60e01df5bf39d2c9ba46a7b9979cf8ff891cb",
  hash ? "sha256-RlS9R/W6yBxfe2cIgRYTgAUbE6cJCWhiqu8Vlkm8C4w=",
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
