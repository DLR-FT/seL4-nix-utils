# builds an seL4 kernel + userland
{ lib
, stdenvNoLibs
, fetchGoogleRepoTool
, writeShellScriptBin
, cmake
, cpio
, dtc
, libxml2
, nanopb
, ninja
, protobuf
, python3Packages
, extraCmakeFlags ? [ ]
}:

stdenvNoLibs.mkDerivation rec {
  pname = "seL4test";
  version = "13.0.0";

  src = fetchGoogleRepoTool {
    url = "https://github.com/seL4/sel4test-manifest.git";
    rev = version;
    hash = "sha256-/SexWcq6GYaAomqsRpwSsyYY40l0qUedVg+dhkJFHao=";
    latestCommitTimestamp = "2024-07-08";
  };

  nativeBuildInputs = [
    # leak cross compiler into eventual devShell, if one uses this drv with inputsFrom
    stdenvNoLibs.cc
    cmake # build tools
    cpio # cpio archive tool
    dtc # device tree compiler
    libxml2 # xmllint
    nanopb # ser/de
    ninja # build tools
    protobuf # to generate ser/de stuff
    python3Packages.seL4-deps # python deps for seL4

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

  # fix /bin/bash et al.
  postPatch = ''
    patchShebangs .
  '';

  env.NIX_CFLAGS_COMPILE = builtins.concatStringsSep " " ([ ]
    # Hotfix for:
    # aarch64-unknown-linux-musl-ld: apps/sel4test-driver/musllibc/build-temp/stage/lib/libc.a(__stdio_exit.o): copy relocation against non-copyable protected symbol `__stdin_used'
    ++ lib.lists.optional (!stdenvNoLibs.hostPlatform.isx86) "-fpic"
  );

  # prevent Nix from injecting any flags meant to harden the build
  hardeningDisable = [ "all" ];

  dontUseCmakeConfigure = true;
  preConfigure = ''
    mkdir build
    cd build
    ../init-build.sh ${lib.strings.escapeShellArgs cmakeFlags}
  '';
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
