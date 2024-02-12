# builds an seL4 kernel + userland
{ lib
, targetStdenv ? null
, pkgsCross ? null
, repoToolFetcher
, cmake
, nanopb
, ninja
, libxml2
, dtc
, cpio
, git
, protobuf
, python3Packages
, config
, extra-seL4-configs ? { }
, extraCmakeFlags ? [ ]
}:

let
  # known seL4 configs and their respective toolchain
  seL4-configs = {
    "ARM_HYP_verified" = "armhf-embedded";
    "ARM_MCS_verified" = "armhf-embedded";
    "ARM_verified" = "arm-embedded";
    "RISCV64_MCS_verified" = "riscv64-embedded";
    "RISCV64_verified" = "riscv64-embedded";
    "X64_verified" = "x86_64-embedded";
  } // extra-seL4-configs;

  # stdenv to be used for this build
  stdenv =
    if targetStdenv == null then
      pkgsCross.${seL4-configs.${config}}.stdenv
    else targetStdenv;

  # interesting flags
  # see: https://docs.sel4.systems/projects/buildsystem/using.html
  #
  # -DAARCH32=TRUE
  # -DAARCH32HF=TRUE
  # -DAARCH64=TRUE
  # -DRISCV32=TRUE
  # -DRISCV64=TRUE
in

# check that the passed seL4 config is known
assert builtins.elem config (builtins.attrNames seL4-configs);

stdenv.mkDerivation rec {
  pname = "seL4";
  version = "unknown";

  src = repoToolFetcher {
    url = "https://github.com/seL4/sel4test-manifest.git";
    tag = "12.1.0";
    hash = "sha256-rkQxfw2wRErR5XKFw2Gnx5iV61oPSNCdOyLZkU5Fojs=";
  };


  nativeBuildInputs = [
    stdenv.cc
    cmake # build tools
    ninja # build tools
    libxml2 # xmllint
    dtc # device tree compiler
    cpio # cpio archive tool
    protobuf # to generate ser/de stuff
    python3Packages.camkes-deps
    python3Packages.seL4-deps
    python3Packages.protobuf

    # weird but ok
    git
  ];

  buildInputs = [
    nanopb # ser/de
  ];

  # fix /bin/bash et al.
  postPatch = ''
    patchShebangs .
    substituteInPlace kernel/tools/circular_includes.py \
      --replace 'file_stack[-1]' 'len(file_stack) > 0 and file_stack[-1]'
  '';

  # /build/source/kernel/src/arch/x86/kernel/cmdline.c: In function 'cmdline_parse':
  # /build/source/kernel/src/arch/x86/kernel/cmdline.c:114:40: error: array subscript 0 is outside array bounds of 'const short unsigned int[0]'
  env.NIX_CFLAGS_COMPILE = "-Wno-error=array-bounds";

  hardeningDisable = [ "all" ];

  dontUseCmakeConfigure = true;
  preConfigure = ''
    mkdir build
    cd build
    ../init-build.sh ${lib.strings.escapeShellArgs cmakeFlags}  '';
  cmakeFlags = [
    "-GNinja"
    "-DCROSS_COMPILER_PREFIX=${stdenv.cc.targetPrefix}"
    "-DCMAKE_TOOLCHAIN_FILE=../kernel/gcc.cmake"
    "-DLibSel4FunctionAttributes=public"
    "-DPLATFORM=pc99"
    "-DRELEASE=TRUE"
    "-DSIMULATION=TRUE"
    "-DVERIFICATION=FALSE"
  ] ++ extraCmakeFlags;

  installPhase = ''
    runHook preInstall
    cp --recursive -- . $out/
    runHook postInstall
  '';
  dontFixup = true;
}
