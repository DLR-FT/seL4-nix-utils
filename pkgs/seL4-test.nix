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
  doCheck ? true,
}:

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
      pkgsBuildBuild.qemu # run the simulation, if available
      protobuf # to generate ser/de stuff

      # fakegit
      (pkgsBuildBuild.writeShellScriptBin "git" ''
        # Taken from https://git.musl-libc.org/cgit/musl/tree/tools/version.sh
        if [[ $@ = "git describe --tags --match 'v[0-9]*'" ]]; then
          echo "${version}"
        else
          >&2 echo "Unknown command: $@"
          exit 1
        fi
      '')
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

    # When cross-compiling, `mkDerivation` automatically overrides `doCheck` to `false`. Therefore
    # this check can not live in the `checkPhase`, and is therefore moved to `postBuild`.
    postBuild = lib.strings.optionalString doCheck ''
      if [[ -x ./simulate ]]
      then
        coproc ( ./simulate )

        while IFS= read -r line <&"''${COPROC[0]}"
        do
          echo "$line"
          case "$line" in
            "Test suite failed."*) exit 1 ;;
            "Test suite passed."*)
              kill "$COPROC_PID" 2>/dev/null
              break 2
            ;;
          esac
        done

        kill "$COPROC_PID" 2>/dev/null
      fi
    '';

    installPhase = ''
      runHook preInstall
      mkdir --parent -- $out
      cp --recursive -- images $out/
      for f in simulate launch_gdb; do
        if [[ -e "$f" ]]; then
          cp -- "$f" "$out/$f"
          substituteInPlace "$out/$f" --replace-quiet "$PWD" "$out"
        fi
      done
      runHook postInstall
    '';
    dontFixup = true;
  }
  // lib.optionalAttrs (src ? unpackPhase) { inherit (src) unpackPhase; }
)
