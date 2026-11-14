{
  stdenv,
  src,
  version,
}:

# inspired by https://github.com/lucaceresoli/zynqmp-pmufw-builder
let
  inherit (stdenv.cc) targetPrefix;
in
stdenv.mkDerivation {
  pname = "zynqmp-pmufw";
  inherit version src;

  preConfigure = ''
    patchShebangs .
    cd lib/sw_apps/zynqmp_pmufw/src

    # disable barrel shifter self test (unknown opcodes bsifi/bsefi)
    sed -e 's|#define XPAR_MICROBLAZE_USE_BARREL 1|#define XPAR_MICROBLAZE_USE_BARREL 0|' -i ../misc/xparameters.h
  '';

  makeFlags = [
    "COMPILER=${targetPrefix}gcc"
    "ARCHIVER=${targetPrefix}ar"
    "CC=${targetPrefix}gcc"
    "OBJCOPY=${targetPrefix}objcopy"
  ];

  installPhase = ''
    runHook preInstall
    ${targetPrefix}objcopy -O binary executable.elf executable.bin
    mkdir --parent -- $out
    cp executable.elf $out/pmufw.elf
    cp executable.bin $out/pmufw.bin
    runHook postInstall
  '';
}
