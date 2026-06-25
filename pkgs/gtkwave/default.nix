{
  stdenv,
  fetchFromGitHub,
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
  version,
  rev,
  hash,
  ...
}:

let
  libfstSrc = fetchFromGitHub {
    owner = "gtkwave";
    repo = "libfst";
    rev = "cf74bef8d0435eceb20524fe6f5674e0ecb68b25";
    hash = "sha256-nrbsMtbnZR4uMOf6MnvEy4QuQtk+Xxqaqzj6ldNunbE=";
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
    "-Dwrap-mode=nodownload"
  ];

  passthru = {
    updateScript = nix-update-script {
      attrPath = "gtkwave";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
}
