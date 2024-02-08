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
, python-seL4-deps
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
      pkgsCross.${seL4-configs.${config}}.stdenv
    else targetStdenv;
in

# check that the passed seL4 config is known
assert builtins.elem config (builtins.attrNames seL4-configs);

stdenv.mkDerivation rec {
  pname = "seL4";
  version = "unknown";

  src = fetchFromGitHub {
    owner = "moritz-meier";
    repo = "sel4-rs";
    rev = "be86b59";
    hash = "sha256-cUI+/cGOaNIjJtbUHoTJnMmL7z3m7XJrWmU8i5Td5ZE=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    # targetStdenv'.cc
    cmake # build tools
    ninja # build tools
    libxml2 # xmllint
    dtc # device tree compiler
    cpio # cpio archive tool
    python-seL4-deps # python build deps
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
  ] ++ extraCmakeFlags;

  installPhase = ''
    runHook preInstall
    cp --recursive -- . $out/
    runHook postInstall
  '';
  dontFixup = true;
}
