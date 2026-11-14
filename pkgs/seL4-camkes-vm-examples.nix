# builds an seL4 kernel + userland
{
  lib,
  stdenv,
  writeText,
  buildPackages,
  cmake,
  cmake-format,
  cpio,
  dtc,
  libxml2,
  nanopb,
  ninja,
  python3Packages,
  qemu,
  ubootTools,
  src,
  version,
  extraCmakeFlags ? [ ],
}:

let
  capDL-makefile = writeText "Makefile" ''
    .RECIPEPREFIX = >
    all:
    > ln --symbolic -- ${lib.getExe buildPackages.capDL-tool} ./
  '';

in
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "seL4-camkes-vm-examples.";
    inherit version src;

    nativeBuildInputs = [
      stdenv.cc
      cmake # build tools
      cpio # cpio archive tool
      dtc # device tree compiler
      libxml2 # xmllint
      nanopb.generator # ser/de
      ninja # build tools
      ubootTools # for mkimage
      python3Packages.protobuf

      # fakegit
      (buildPackages.writeShellScriptBin "git" ''
        # Taken from https://git.musl-libc.org/cgit/musl/tree/tools/version.sh
        if [[ $@ = "git describe --tags --match 'v[0-9]*'" ]]; then
          echo "${finalAttrs.version}"
        else
          >&2 echo "Unknown command: $@"
          exit 1
        fi
      '')
    ]
    ++ import ./camkes-deps.nix {
      inherit cmake-format python3Packages;
    };

    depsBuildBuild = [
      qemu # qemu-system-aarch64
    ];

    postPatch = ''
      # fix /bin/bash et al.
      patchShebangs .

      # avoid from-scratch compilation of capDL-tool
      cp -- ${capDL-makefile} projects/capdl/capDL-tool/Makefile

      # camkes still depends on `future.utils,` but the future package is not released for
      # python 3.13, which is the default python distribution in nixpkgs-25.11
      patch -p1 --directory=projects/camkes-tool < ${../patches/camkes-python-no-future.patch}

      # CMake rejects `<` in if() (upstream typo for LESS)
      substituteInPlace projects/camkes-tool/camkes.cmake \
        --replace-fail '(''${CAmkESDefaultAffinity} < 0)' '(''${CAmkESDefaultAffinity} LESS 0)'
    '';

    hardeningDisable = [ "all" ];

    preConfigure = ''
      cd projects/vm-examples

      # TODO remove workaround for https://github.com/seL4/camkes-tool/issues/154
      sed --in-place -- 's|"PYTHONPATH=\([^"]*\)"|"PYTHONPATH=\1:'"$PYTHONPATH"'"|g' ../../projects/camkes-tool/camkes.cmake
    '';

    cmakeFlags = [
      "-GNinja"
      "-DCROSS_COMPILER_PREFIX=${stdenv.cc.targetPrefix}"
      "-DC_PREPROCESSOR=${stdenv.cc}/bin/${stdenv.cc.targetPrefix}cpp"
      "-DCMAKE_TOOLCHAIN_FILE=../../kernel/gcc.cmake"
    ]
    ++ lib.lists.optionals (stdenv.hostPlatform.isAarch32) [
      "-DAARCH32=1"

      # On armv7, the TLS register is not correctly discovered, leading to this error:
      #
      # CMake Error at /build/source/projects/musllibc/CMakeLists.txt:48 (message):
      #   Unsupported thread-local-storage (TLS) settings detected: KernelSel4Arch is
      #   set to aarch32.  KernelArmTLSReg is set to tpidru but only tpidruro is
      #   supported with this version of musllibc.
      "-DKernelArmTLSReg=tpidruro"
    ]
    ++ lib.lists.optional (stdenv.hostPlatform.isAarch64) "-DAARCH64=1"
    ++ lib.lists.optional (stdenv.hostPlatform.isRiscV64) "-DRISCV64=1"
    ++ lib.lists.optional (stdenv.hostPlatform.isRiscV32) "-DRISCV32=1"
    ++ extraCmakeFlags;

    installPhase = ''
      runHook preInstall
      cp --recursive -- . $out/
      if [[ -e "$out/simulate" ]]; then
        substituteInPlace "$out/simulate" \
          --replace-quiet 'default="qemu-system-' "default=\"${buildPackages.qemu}/bin/qemu-system-" \
          --replace-quiet 'default="images/' "default=\"$out/images/"
      fi
      runHook postInstall
    '';
    dontFixup = true;
  }
  // lib.optionalAttrs (src ? unpackPhase) { inherit (src) unpackPhase; }
)
