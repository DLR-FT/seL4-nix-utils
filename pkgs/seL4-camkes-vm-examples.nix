# builds an seL4 kernel + userland
{ lib
, stdenvNoLibs
, fetchGoogleRepoTool
, writeShellScriptBin
, cmake
, nanopb
, ninja
, libxml2
, dtc
, cpio
, protobuf
, python3
, qemu
, extraCmakeFlags ? [ ]
, stack
}:

stdenvNoLibs.mkDerivation rec {
  pname = "seL4-camkes-vm-examples.";
  version = "2024-03-20";

  src = fetchGoogleRepoTool {
    url = "https://github.com/seL4/camkes-vm-examples-manifest.git";
    rev = "9c0888e";
    hash = "sha256-72ChKOOU9RX1OqVWOQd4ekVn7WmR/urpToCe3Kih90I=";
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
    (python3.withPackages (ps: with ps; [ camkes-deps protobuf seL4-deps ]))
    stack

    # fakegit
    (writeShellScriptBin "git" ''
      # Taken from https://git.musl-libc.org/cgit/musl/tree/tools/version.sh
      if [[ $@ = "git describe --tags --match 'v[0-9]*'" ]]; then
        echo "${version}"
      else
        >&2 echo "Unknown command: $@"
        exit 1
      fi
    '')
  ];

  depsBuildBuild = [
    qemu # qemu-system-aarch64
  ];

  # fake a git repo for musl
  postFixup = ''
    touch projects/musllibc/.git
  '';

  # fix /bin/bash et al.
  postPatch = ''
    patchShebangs .
    substituteInPlace kernel/tools/circular_includes.py \
      --replace 'file_stack[-1]' 'len(file_stack) > 0 and file_stack[-1]'
  '';

  env.NIX_CFLAGS_COMPILE = builtins.concatStringsSep " " ([ ]
    # Hotfix for:
    # aarch64-unknown-linux-musl-ld: apps/sel4test-driver/musllibc/build-temp/stage/lib/libc.a(__stdio_exit.o): copy relocation against non-copyable protected symbol `__stdin_used'
    ++ lib.lists.optional (!stdenvNoLibs.hostPlatform.isx86) "-fpic"
  );

  hardeningDisable = [ "all" ];

  dontUseCmakeConfigure = true;
  preConfigure = ''
    mkdir home
    export HOME="$PWD/home"
    mkdir build
    cd build
    ../init-build.sh ${lib.strings.escapeShellArgs cmakeFlags}  '';
  cmakeFlags = [
    "-GNinja"
    "-DCROSS_COMPILER_PREFIX=${stdenvNoLibs.cc.targetPrefix}"
    "-DC_PREPROCESSOR=${stdenvNoLibs.cc}/bin/${stdenvNoLibs.cc.targetPrefix}cpp"
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
