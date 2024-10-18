# builds an seL4 kernel
{ lib
, stdenv
, fetchFromGitHub
, cmake
, ninja
, libxml2
, dtc
, cpio
, python3Packages
, verifiedConfig ? null
, extraVerifiedConfigs ? [ ]
}:


let
  # known seL4 configs
  knownVerifiedConfigs = [
    "ARM_HYP_verified"
    "ARM_MCS_verified"
    "ARM_verified"
    "RISCV64_MCS_verified"
    "RISCV64_verified"
    "X64_verified"
  ] ++ extraVerifiedConfigs;
in

# check that the passed seL4 config is known
assert if verifiedConfig != null then builtins.elem verifiedConfig knownVerifiedConfigs else true;

stdenv.mkDerivation rec {
  pname = "seL4";
  version = "13.0.0";

  src = fetchFromGitHub {
    owner = pname;
    repo = pname;
    rev = version;
    hash = "sha256-sFmOFoXwe1AsG0JLI2+QKEitmecxik9lxXUqf4QRysk=";
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
  ] ++ lib.lists.optional (verifiedConfig != null) "-C../configs/${verifiedConfig}.cmake";

  dontFixup = true;
}
