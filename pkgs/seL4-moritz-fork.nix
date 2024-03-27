# builds an seL4 kernel + userland
{ lib
, targetStdenv ? null
, pkgsCross ? null
, fetchFromGitHub
, cmake
, ninja
, libxml2
, dtc
, cpio
, python3Packages
, config
, extra-seL4-configs ? { }
, extraCmakeFlags ? [ ]
}:

let
  # known seL4 configs and their respective toolchain
  seL4-configs = {
    "ARM_HYP_verified" = "armhf-embedded";
    "ARM_MCS_verified" = "armhf-embedded";
    "ARM_verified" = "arm-embedded";
    "RISCV64_MCS_verified" = "riscv64-embedded";
    "RISCV64_verified" = "riscv64-embedded";
    "X64_verified" = "x86_64-embedded";
  } // extra-seL4-configs;

  # stdenv to be used for this build
  stdenv =
    if targetStdenv == null then
      pkgsCross.${seL4-configs.${config}}.stdenvNoLibs
    else targetStdenv;
in

# check that the passed seL4 config is known
assert builtins.elem config (builtins.attrNames seL4-configs);

stdenv.mkDerivation {
  pname = "seL4";
  version = "unknown";

  src = fetchFromGitHub {
    owner = "moritz-meier";
    repo = "sel4-rs";
    rev = "326f255";
    hash = "sha256-xoBv642Z8c07V/jUW0su8/Jjc0EhkljIhED9E6VNdO4=";
    fetchSubmodules = true;
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
    cd sys/sel4-sys/sel4
    patchShebangs .
  '';

  cmakeFlags = [
    "-GNinja"
    "-DCROSS_COMPILER_PREFIX=${stdenv.cc.targetPrefix}"
    "-DCMAKE_TOOLCHAIN_FILE=../kernel/gcc.cmake"
    "-DLibSel4FunctionAttributes=public"
  ]
  # The Nix provided RISCV compiler defaults to having a double precision FPU. This fixes linker
  # errors due to soft/hard FPU missmatch.
  ++ (lib.lists.optional (lib.strings.hasInfix "RISCV64" config) "-DKernelRiscvExtD=true")
  ++ extraCmakeFlags;

  installPhase = ''
    runHook preInstall
    cp --recursive -- . $out/
    runHook postInstall
  '';
  dontFixup = true;
}
