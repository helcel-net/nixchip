{
  fetchFromGitHub,
  ghdl,
  nix-update-script,
  version ? "unstable-2026-07-01",
  rev ? "0bd365acf02651485a3b5d6c2ed2c76744cf2b28",
  hash ? "sha256-a9ZSy84Z0F7QrCa6TaIBaXr51YVabc9ZES3dqgO3r7s=",
  ...
}:

ghdl.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "ghdl";
    repo = "ghdl";
    inherit rev hash;
  };
  postPatch = (old.postPatch or "") + ''
    # Nix sets SOURCE_DATE_EPOCH which ghdl (post-6.0.0) uses as the analysis
    # timestamp for every VHDL unit.  This produces epoch-based timestamps like
    # "19700101000001.000" that are lexicographically less than the std.standard
    # package's hardcoded timestamp "20020601000000.000", causing false
    # "is obsoleted by package standard" errors during both library bootstrap
    # and user VHDL analysis.  Setting standard's timestamp to all-zeros makes
    # it always appear as the oldest unit, which is semantically correct since
    # the standard package never changes between analyses.
    sed -i 's/"20020601000000\.000"/"00000000000000.000"/' \
      src/vhdl/vhdl-std_package.adb
    # Also unset SOURCE_DATE_EPOCH for the VHDL library bootstrap so the
    # installed library files carry real timestamps.
    sed -i 's|$(MAKE) -f $(srcdir)/libraries/Makefile.inc|env -u SOURCE_DATE_EPOCH $(MAKE) -f $(srcdir)/libraries/Makefile.inc|g' \
      Makefile.in
  '';
  passthru = (old.passthru or { }) // {
    updateScript = nix-update-script {
      attrPath = "ghdl";
      extraArgs = [ "--version=branch" ];
    };
    nixchipUpdate = true;
    nixchipCI = true;
  };
})
