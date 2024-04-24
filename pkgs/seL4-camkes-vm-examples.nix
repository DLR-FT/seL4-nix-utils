# builds an seL4 kernel + userland
{ lib
, stdenvNoLibs
, fetchGoogleRepoTool
, fetchurl
, writeShellScriptBin
, writeText
, capDL-tool
, cmake
, nanopb
, ninja
, libxml2
, dtc
, cpio
, protobuf
, python3
, qemu
, ubootTools
, extraCmakeFlags ? [ ]
, stack
}:

let
  capDL-makefile = writeText "Makefile" ''
    .RECIPEPREFIX = >
    all:
    > ln --symbolic -- ${lib.getExe capDL-tool} ./
  '';
in

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
    ubootTools # for mkimage
    (python3.withPackages (ps: with ps; [ camkes-deps protobuf seL4-deps ]))

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

  # required because the musllibc fork of seL4 is so old it won't compile with gcc12
  # see https://github.com/seL4/musllibc/issues/19#issuecomment-1841713558
  # and https://www.mail-archive.com/devel@sel4.systems/msg04088.html
  patches = [
    # introduces base for new hidden macro
    (fetchurl {
      url = "https://git.musl-libc.org/cgit/musl/patch/src/include/features.h?id=13d1afa46f8098df290008c681816c9eb89ffbdb";
      hash = "sha256-2W5iKJP9SdXy+SdcX5dEBLGSjJMrFK1OKHn2BZGJJpc=";
    })

    # introduces new way to access stdio stuff, relying on hidden symbol macro
    (fetchurl {
      url = "https://git.musl-libc.org/cgit/musl/patch/?id=d8f2efa708a027132d443f45a8c98a0c7c1b2d77";
      hash = "sha256-kt30c6joUxU7BcTyq/TcY9+YgJ5Cw01cOTGn8hQpCOU=";
    })

    # make sure the new definition of hidden macro is seen by the stdio stuff
    ../patches/musslibc-add-features.h-to-stdio_impl.h.patch
  ];
  patchFlags = [ "-p1" "--directory=projects/musllibc" ];

  postPatch = ''
    # fix /bin/bash et al.
    patchShebangs .
    substituteInPlace kernel/tools/circular_includes.py \
      --replace 'file_stack[-1]' 'len(file_stack) > 0 and file_stack[-1]'

    # avoid from-scratch compilation of capDL-tool
    cp -- ${capDL-makefile} projects/capdl/capDL-tool/Makefile
  '';

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
