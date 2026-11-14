# builds an seL4 kernel + userland
{
  lib,
  stdenv,
  pkgsBuildBuild,
  cmake,
  cmake-format,
  cpio,
  dtc,
  libxml2,
  nanopb,
  ninja,
  protobuf,
  python3Packages,
  src,
  version,
  extraCmakeFlags ? [ ],
}:

let
  seL4Common = import ./seL4-common.nix { inherit lib stdenv; };
in
stdenv.mkDerivation (
  {
    pname = "seL4test";
    inherit version src;

    nativeBuildInputs = [
      cmake # build tools
      cpio # cpio archive tool
      dtc # device tree compiler
      libxml2 # xmllint
      nanopb.generator # ser/de
      ninja # build tools
      protobuf # to generate ser/de stuff
    ]
    ++ import ./seL4-deps.nix {
      inherit cmake-format python3Packages;
    };

    # fix /bin/bash et al.
    postPatch = ''
      patchShebangs .
    '';

    env.NIX_CFLAGS_COMPILE = lib.strings.concatStringsSep " " [
      /*
        Fix for https://github.com/seL4/sel4test/issues/127
        Gcc compiling for an x86 `-elf` target treats single forward slashed
        (`/`) as beginning of comments, which breaks the alignment tests in
        `projects/sel4test/apps/sel4test-tests/src/arch/x86/tests/alignment_asm.S`
      */
      (lib.strings.optionalString (stdenv.hostPlatform.isx86) "-Wa,--divide")
    ];

    # prevent Nix from injecting any flags meant to harden the build
    hardeningDisable = [ "all" ];

    preConfigure = ''
      cd projects/sel4test
    '';
    cmakeFlags = seL4Common.baseCmakeFlags ++ extraCmakeFlags;

    installPhase = seL4Common.mkInstallPhase pkgsBuildBuild.qemu;
    dontFixup = true;
  }
  // lib.optionalAttrs (src ? unpackPhase) { inherit (src) unpackPhase; }
)
