# builds an seL4 kernel
{ lib
, stdenvNoLibs
, fetchFromGitHub
, cmake
, ninja
, libxml2
, dtc
, cpio
, python3Packages
, config ? null
, extraCmakeFlags ? [ ]
}:

let
  softFloat = stdenvNoLibs.hostPlatform.gcc.float or (stdenvNoLibs.hostPlatform.parsed.abi.float or "hard") == "soft";
in
stdenvNoLibs.mkDerivation rec {
  pname = "seL4";
  version = "12.1.0";

  src = fetchFromGitHub {
    owner = pname;
    repo = pname;
    rev = version;
    hash = "sha256-3MSX7f6q6YiBG/FcB/KjeRloInnwTsgLg84m47lD/eI=";
  };

  nativeBuildInputs = [
    stdenvNoLibs.cc
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
    "-DCROSS_COMPILER_PREFIX=${stdenvNoLibs.cc.targetPrefix}"
    "-DCMAKE_TOOLCHAIN_FILE=../gcc.cmake"
  ]
  ++ lib.lists.optional (config != null) "-C../configs/${config}.cmake"
  ++ lib.lists.optional (stdenvNoLibs.hostPlatform.isAarch32 && softFloat) "-DAARCH32=1"
  ++ lib.lists.optional (stdenvNoLibs.hostPlatform.isAarch32 && !softFloat) "-DAARCH32HF=1"
  ++ lib.lists.optional (stdenvNoLibs.hostPlatform.isAarch64) "-DAARCH64=1"
  ++ lib.lists.optional (stdenvNoLibs.hostPlatform.isRiscV64) "-DRISCV64=1"
  ++ lib.lists.optional (stdenvNoLibs.hostPlatform.isRiscV32) "-DRISCV32=1"
  ++ extraCmakeFlags;

  installPhase = ''
    runHook preInstall
    cp --recursive -- .. $out/
    runHook postInstall
  '';
  dontFixup = true;
}
