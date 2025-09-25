# builds an seL4 kernel + userland
{
  lib,
  stdenv,
  fetchGoogleRepoTool,
  buildPackages,
  cmake,
  cpio,
  dtc,
  libxml2,
  nanopb,
  ninja,
  protobuf,
  python3Packages,
  extraCmakeFlags ? [ ],
}:

stdenv.mkDerivation rec {
  pname = "seL4test";
  version = "13.0.0";

  src = fetchGoogleRepoTool {
    url = "https://github.com/seL4/sel4test-manifest.git";
    rev = version;
    hash = "sha256-mEcimqgii4ohiJbXz1pNSqthWObrbnLmqEn8yQpkUKo=";
  };

  nativeBuildInputs = [
    cmake # build tools
    cpio # cpio archive tool
    dtc # device tree compiler
    libxml2 # xmllint
    nanopb.generator # ser/de
    ninja # build tools
    protobuf # to generate ser/de stuff
    python3Packages.seL4-deps # python deps for seL4

    # fakegit
    (buildPackages.writeShellScriptBin "git" ''
      # Taken from https://git.musl-libc.org/cgit/musl/tree/tools/version.sh
      if [[ $@ = "git describe --tags --match 'v[0-9]*'" ]]; then
        echo "${version}"
      else
        >&2 echo "Unknown command: $@"
        exit 1
      fi
    '')
  ];

  # fix /bin/bash et al.
  postPatch = ''
    patchShebangs .
  ''
  # Patch old musllibc to work with new bintools
  # TODO remove this once https://github.com/seL4/sel4test-manifest/issues/21 is fixed
  + ''
    pushd projects/musllibc
    patch -p1 < ${../patches/seL4-compile-musl-on-recent-gcc-1.patch}
    patch -p1 < ${../patches/seL4-compile-musl-on-recent-gcc-2.patch}
    popd
  '';

  # Fix for https://github.com/seL4/sel4test/issues/127
  # Gcc compiling for an x86 -elf target treats single forward slashed (`/`) as
  # beginning of comments, which breaks the alignment tests in
  # projects/sel4test/apps/sel4test-tests/src/arch/x86/tests/alignment_asm.S
  env.NIX_CFLAGS_COMPILE = lib.strings.optionalString (stdenv.hostPlatform.isx86) "-Wa,--divide";

  # prevent Nix from injecting any flags meant to harden the build
  hardeningDisable = [ "all" ];

  preConfigure = ''
    cd projects/sel4test
  '';
  cmakeFlags = [
    "-GNinja"
    "-DCROSS_COMPILER_PREFIX=${stdenv.cc.targetPrefix}"
    "-DCMAKE_TOOLCHAIN_FILE=../../kernel/gcc.cmake"
  ]
  ++ lib.lists.optional (stdenv.hostPlatform.isAarch32) "-DAARCH32=1"
  ++ lib.lists.optional (stdenv.hostPlatform.isAarch64) "-DAARCH64=1"
  ++ lib.lists.optional (stdenv.hostPlatform.isRiscV64) "-DRISCV64=1"
  ++ lib.lists.optional (stdenv.hostPlatform.isRiscV32) "-DRISCV32=1"
  ++ extraCmakeFlags;

  installPhase = ''
    runHook preInstall
    cp --recursive -- . $out/
    runHook postInstall
  '';
  dontFixup = true;
}
