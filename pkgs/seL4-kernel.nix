# builds an seL4 kernel
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  libxml2,
  dtc,
  cpio,
  python3Packages,
  verifiedConfig ? null,
  extraVerifiedConfigs ? [ ],
  extraCmakeFlags ? [ ],
}:

let
  # known seL4 configs
  knownVerifiedConfigs = [
    "AARCH64_bcm2711_verified"
    "AARCH64_hikey_verified"
    "AARCH64_imx8mm_verified"
    "AARCH64_imx8mq_verified"
    "AARCH64_imx93_verified"
    "AARCH64_maaxboard_verified"
    "AARCH64_odroidc2_verified"
    "AARCH64_odroidc4_verified"
    "AARCH64_rockpro64_verified"
    "AARCH64_tqma_verified"
    "AARCH64_tx1_verified"
    "AARCH64_ultra96v2_verified"
    "AARCH64_verified"
    "AARCH64_zynqmp_verified"
    "ARM_HYP_exynos5410_verified"
    "ARM_HYP_exynos5_verified"
    "ARM_HYP_verified"
    "ARM_MCS_verified"
    "ARM_am335x_verified"
    "ARM_bcm2837_verified"
    "ARM_exynos4_verified"
    "ARM_exynos5410_verified"
    "ARM_exynos5422_verified"
    "ARM_hikey_verified"
    "ARM_imx8mm_verified"
    "ARM_omap3_verified"
    "ARM_tk1_verified"
    "ARM_verified"
    "ARM_zynq7000_verified"
    "ARM_zynqmp_verified"
    "RISCV64_MCS_verified"
    "RISCV64_verified"
    "X64_verified"
    "seL4Config"
  ]
  ++ extraVerifiedConfigs;
in
# check that the passed seL4 config is known
assert if verifiedConfig != null then builtins.elem verifiedConfig knownVerifiedConfigs else true;

stdenv.mkDerivation rec {
  pname = "seL4";
  version = "14.0.0";

  src = fetchFromGitHub {
    owner = pname;
    repo = pname;
    rev = version;
    hash = "sha256-kzRV3qIsfyIFoc2hT6l0cIyR6zLD4yHcPXCAbGAQGsk=";
  };

  nativeBuildInputs = [
    cmake # build tools
    ninja # build tools
    libxml2 # xmllint
    dtc # device tree compiler
    cpio # cpio archive tool
    python3Packages.seL4-deps # python build deps
  ];

  # fix /bin/bash et al.
  postPatch = ''
    patchShebangs .
  '';

  cmakeFlags = [
    "-GNinja"
    "-DCROSS_COMPILER_PREFIX=${stdenv.cc.targetPrefix}"
    "-DCMAKE_TOOLCHAIN_FILE=../gcc.cmake"
  ]
  ++ lib.lists.optional (verifiedConfig != null) "-C../configs/${verifiedConfig}.cmake"
  ++ extraCmakeFlags;

  dontFixup = true;
}
