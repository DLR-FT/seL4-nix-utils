# builds an seL4 kernel + userland
{ lib
, stdenvNoLibs
, fetchGoogleRepoTool
, cmake
, nanopb
, ninja
, libxml2
, dtc
, cpio
, git
, protobuf
, python3Packages
, extraCmakeFlags ? [ ]
}:

stdenvNoLibs.mkDerivation rec {
  pname = "seL4";
  version = "unknown";

  src = fetchGoogleRepoTool {
    url = "https://github.com/seL4/sel4test-manifest.git";
    rev = "12.1.0";
    hash = "sha256-13Q2BP+WD8JuSZbm7NUu8S1fZiE7KB3Bwew1wxzwIAs=";
  };

  nativeBuildInputs = [
    stdenvNoLibs.cc
    cmake # build tools
    cpio # cpio archive tool
    dtc # device tree compiler
    libxml2 # xmllint
    nanopb # ser/de
    ninja # build tools
    protobuf # to generate ser/de stuff
    python3Packages.camkes-deps
    python3Packages.protobuf
    python3Packages.seL4-deps

    # weird but ok
    git
  ];

  # fix /bin/bash et al.
  postPatch = ''
    patchShebangs .
    substituteInPlace kernel/tools/circular_includes.py \
      --replace 'file_stack[-1]' 'len(file_stack) > 0 and file_stack[-1]'
  '';

  # /build/source/kernel/src/arch/x86/kernel/cmdline.c: In function 'cmdline_parse':
  # /build/source/kernel/src/arch/x86/kernel/cmdline.c:114:40: error: array subscript 0 is outside array bounds of 'const short unsigned int[0]'
  env.NIX_CFLAGS_COMPILE = "-Wno-error=array-bounds -fpic";

  hardeningDisable = [ "all" ];

  dontUseCmakeConfigure = true;
  preConfigure = ''
    mkdir build
    cd build
    ../init-build.sh ${lib.strings.escapeShellArgs cmakeFlags}  '';
  cmakeFlags = [
    "-GNinja"
    "-DCROSS_COMPILER_PREFIX=${stdenvNoLibs.cc.targetPrefix}"
    "-DCMAKE_TOOLCHAIN_FILE=../kernel/gcc.cmake"
  ]
  ++ lib.lists.optional (stdenvNoLibs.hostPlatform.isAarch32) "-DAARCH32=1"
  ++ lib.lists.optional (stdenvNoLibs.hostPlatform.isAarch64) "-DAARCH64=1"
  ++ lib.lists.optional (stdenvNoLibs.hostPlatform.isRiscV64) "-DRISCV64=1"
  ++ lib.lists.optional (stdenvNoLibs.hostPlatform.isRiscV32) "-DRISCV32=1"
  ++ extraCmakeFlags;

  installPhase = ''
    runHook preInstall
    cp --recursive -- . $out/
    runHook postInstall
  '';
  dontFixup = true;
}
