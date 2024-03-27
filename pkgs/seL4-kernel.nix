# builds an seL4 kernel
{ targetStdenv ? null
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

stdenv.mkDerivation rec {
  pname = "seL4";
  version = "12.1.0";

  src = fetchFromGitHub {
    owner = pname;
    repo = pname;
    rev = version;
    hash = "sha256-3MSX7f6q6YiBG/FcB/KjeRloInnwTsgLg84m47lD/eI=";
  };

  nativeBuildInputs = [
    # targetStdenv'.cc
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
    "-C../configs/${config}.cmake"
    "-DCROSS_COMPILER_PREFIX=${stdenv.cc.targetPrefix}"
    "-DCMAKE_TOOLCHAIN_FILE=../gcc.cmake"
  ];

  installPhase = ''
    runHook preInstall
    cp --recursive -- .. $out/
    runHook postInstall
  '';
  dontFixup = true;
}
