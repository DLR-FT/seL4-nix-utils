{
  lib,
  stdenv,
}:

let
  archCmakeFlags =
    lib.lists.optional stdenv.hostPlatform.isAarch32 "-DAARCH32=1"
    ++ lib.lists.optional stdenv.hostPlatform.isAarch64 "-DAARCH64=1"
    ++ lib.lists.optional stdenv.hostPlatform.isRiscV64 "-DRISCV64=1"
    ++ lib.lists.optional stdenv.hostPlatform.isRiscV32 "-DRISCV32=1";

  baseCmakeFlags = [
    "-GNinja"
    "-DCROSS_COMPILER_PREFIX=${stdenv.cc.targetPrefix}"
    "-DCMAKE_TOOLCHAIN_FILE=../../kernel/gcc.cmake"
  ]
  ++ archCmakeFlags;

  mkInstallPhase = qemuPkg: ''
    runHook preInstall
    mkdir --parent -- $out
    cp --recursive -- images $out/
    for f in simulate launch_gdb; do
      if [[ -e "$f" ]]; then
        cp -- "$f" "$out/$f"
        substituteInPlace "$out/$f" \
          --replace-quiet "$PWD" "$out" \
          --replace-quiet 'default="qemu-system-' "default=\"${qemuPkg}/bin/qemu-system-" \
          --replace-quiet "default='qemu-system-" "default='${qemuPkg}/bin/qemu-system-" \
          --replace-quiet 'default="images/' "default=\"$out/images/" \
          --replace-quiet "default='images/" "default='$out/images/"
      fi
    done
    runHook postInstall
  '';
in
{
  inherit
    archCmakeFlags
    baseCmakeFlags
    mkInstallPhase
    ;
}
