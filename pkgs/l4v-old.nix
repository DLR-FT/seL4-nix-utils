{ stdenv
, fetchGoogleRepoTool
, writeShellApplication
, which
, perl
, isabelle
, cmake
, dtc
, mlton
, ninja
, pkgsCross
, libxml2
, python3Packages
}:

let
  fakeHostname = writeShellApplication {
    name = "hostname";
    text = ''
      echo nixos
    '';
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "L4.verified";
  version = "1.11";

  src = fetchGoogleRepoTool {
    url = "https://github.com/seL4/verification-manifest";
    rev = "2b434d1957eba420782f10f90e58f0b93ee3a4b7"; # 2024-10-11
    manifest = "13.0.0.xml";
    hash = "sha256-GTjofiun3TWlKdHRegWJNIitRzcZTGuSZQG1tmLpBg0=";
  };
  # src = fetchFromGitHub {
  #   owner = "seL4";
  #   repo = "l4v";
  #   rev = "autocorres-${finalAttrs.version}";
  #   hash = "sha256-Rv3lhx3CE7jW9P+nW3JiYZXnMmr+qFcAiK/TMziYxyE=";
  # };

  nativeBuildInputs = [
    dtc
    libxml2 # xmllint
    isabelle
    mlton
    which
    perl
    python3Packages.seL4-deps # python build deps

    fakeHostname
    cmake
    ninja

    # compilers
    pkgsCross.aarch64-embedded.stdenv.cc.bintools
    pkgsCross.aarch64-embedded.stdenv.cc.cc
    pkgsCross.arm-embedded.stdenv.cc.bintools
    pkgsCross.arm-embedded.stdenv.cc.cc
    pkgsCross.armv7l-hf-multiplatform.stdenv.cc #
    pkgsCross.riscv64-embedded.stdenv.cc.bintools
    pkgsCross.riscv64-embedded.stdenv.cc.cc
  ];

  preUnpack = ''
    HOME="$PWD/home"
    mkdir --parent -- "$HOME"
  '';

  dontUseCmakeConfigure = true;

  postPatch = ''
    # patch in our isabell
    rm --force --recursive -- isabelle
    ln --force --symbolic -- ${isabelle} isabelle

    patchShebangs .
    # grep -R
    # arm-linux-gnueabi-gcc arm-none-eabi-gcc
  '';

  preBuild = ''
    # cd l4v/proof

    cd l4v/spec
  '';

  env = {
    CC = "${stdenv.cc.targetPrefix}cc";
    ASM = "${stdenv.cc.targetPrefix}as";
  };

  buildPhase = ''
    runHook preBuild

    # make all

    make c-kernel L4V_ARCH=ARM

    runHook postBuild
  '';
})
