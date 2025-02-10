# builds an seL4 kernel + userland
{
  lib,
  stdenvNoLibs,
  fetchGoogleRepoTool,
  writeText,
  buildPackages,
  cmake,
  cpio,
  dtc,
  libxml2,
  nanopb,
  ninja,
  qemu,
  ubootTools,
  extraCmakeFlags ? [ ],
}:

let
  capDL-makefile = writeText "Makefile" ''
    .RECIPEPREFIX = >
    all:
    > ln --symbolic -- ${lib.getExe buildPackages.capDL-tool} ./
  '';

in
stdenvNoLibs.mkDerivation rec {
  pname = "seL4-camkes-vm-examples.";
  version = "camkes-3.11.0";

  src = fetchGoogleRepoTool {
    url = "https://github.com/seL4/camkes-vm-examples-manifest.git";
    rev = "camkes-3.11.0";
    hash = "sha256-DTQDk3/xBiK78s+tQrXyDOPzXHADjj3cKM872yxIRJU=";
  };

  nativeBuildInputs = [
    stdenvNoLibs.cc
    cmake # build tools
    cpio # cpio archive tool
    dtc # device tree compiler
    libxml2 # xmllint
    nanopb # ser/de
    ninja # build tools
    ubootTools # for mkimage
    (buildPackages.python3.withPackages (
      ps: with ps; [
        camkes-deps
        seL4-deps
        protobuf
      ]
    ))

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
  depsBuildBuild = [
    qemu # qemu-system-aarch64
  ];

  postPatch =
    ''
      # fix /bin/bash et al.
      patchShebangs .
      substituteInPlace kernel/tools/circular_includes.py \
        --replace 'file_stack[-1]' 'len(file_stack) > 0 and file_stack[-1]'

      # avoid from-scratch compilation of capDL-tool
      cp -- ${capDL-makefile} projects/capdl/capDL-tool/Makefile
    ''

    # required because the musllibc fork of seL4 is so old it won't compile with gcc12
    # see https://github.com/seL4/musllibc/issues/19#issuecomment-1841713558
    # and https://www.mail-archive.com/devel@sel4.systems/msg04088.html
    + ''
      pushd projects/musllibc
      patch -p1 < ${../patches/seL4-compile-musl-on-recent-gcc-1.patch}
      patch -p1 < ${../patches/seL4-compile-musl-on-recent-gcc-2.patch}
      popd
    '';

  hardeningDisable = [ "all" ];

  dontUseCmakeConfigure = true;
  preConfigure = ''
    mkdir home
    export HOME="$PWD/home"
    mkdir build
    cd build
    ../init-build.sh ${lib.strings.escapeShellArgs cmakeFlags}  '';
  cmakeFlags =
    [
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
