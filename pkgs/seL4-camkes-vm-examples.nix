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
  ubootTools,
  src,
  version,
  extraCmakeFlags ? [ ],
}:

let
  seL4Common = import ./seL4-common.nix { inherit lib stdenv; };

  capDL-makefile = writeText "Makefile" ''
    .RECIPEPREFIX = >
    all:
    > ln --symbolic -- ${lib.getExe buildPackages.capDL-tool} ./
  '';
in
stdenv.mkDerivation (
  {
    pname = "seL4-camkes-vm-examples.";
    inherit version src;

    nativeBuildInputs = [
      stdenv.cc
      buildPackages.qemu # used at configure time to extract virt DTB
      cmake # build tools
      cpio # cpio archive tool
      dtc # device tree compiler
      libxml2 # xmllint
      nanopb.generator # ser/de
      ninja # build tools
      ubootTools # for mkimage
      python3Packages.protobuf
    ]
    ++ import ./camkes-deps.nix {
      inherit cmake-format python3Packages;
    };

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

    cmakeFlags =
      seL4Common.baseCmakeFlags
      ++ [
        "-DC_PREPROCESSOR=${stdenv.cc}/bin/${stdenv.cc.targetPrefix}cpp"
      ]
      ++ lib.lists.optionals (stdenv.hostPlatform.isAarch32) [
        # On armv7, the TLS register is not correctly discovered, leading to this error:
        #
        # CMake Error at /build/source/projects/musllibc/CMakeLists.txt:48 (message):
        #   Unsupported thread-local-storage (TLS) settings detected: KernelSel4Arch is
        #   set to aarch32.  KernelArmTLSReg is set to tpidru but only tpidruro is
        #   supported with this version of musllibc.
        "-DKernelArmTLSReg=tpidruro"
      ]
      ++ extraCmakeFlags;

    installPhase = seL4Common.mkInstallPhase buildPackages.qemu;
    dontFixup = true;
  }
  // lib.optionalAttrs (src ? unpackPhase) { inherit (src) unpackPhase; }
)
