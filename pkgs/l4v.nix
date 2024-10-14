{ stdenvNoCC
, fetchGoogleRepoTool
, which
, isabelle
, cmake
, mlton
, ninja
, pkgsCross
, python3Packages
, openjdk_headless
}:

stdenvNoCC.mkDerivation (finalAttrs: {
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
    which
    isabelle
    mlton
    openjdk_headless

    cmake
    ninja

    # compilers
    pkgsCross.aarch64-embedded.stdenv.cc.bintools.bintools
    pkgsCross.aarch64-embedded.stdenv.cc.cc
    pkgsCross.arm-embedded.stdenv.cc.bintools.bintools
    pkgsCross.arm-embedded.stdenv.cc.cc
    pkgsCross.riscv64-embedded.stdenv.cc.bintools.bintools
    pkgsCross.riscv64-embedded.stdenv.cc.cc
  ];

  preUnpack = ''
    HOME="$PWD/home"
    mkdir --parent -- "$HOME"
  '';

  dontUseCmakeConfigure = true;

  # preConfigure = ''
  #   rm --force --recursive -- isabelle
  #   ln --force --symbolic -- ${isabelle} isabelle
  # '';

  prePatch = ''
    patchShebangs .
  '';

  preBuild = ''
    cd l4v/proof
  '';

  buildPhase = ''
    runHook preBuild

    file /build/source/l4v/isabelle/bin/isabelle
    make all

    runHook postBuild
  '';
})
