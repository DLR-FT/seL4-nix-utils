{ stdenvNoCC
, fetchGoogleRepoTool
, which
, isabelle
, cmake
, mlton
, ninja
, pkgsCross
, python3Packages
, fontconfig
, openjdk_headless
, autoPatchelfHook
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
    autoPatchelfHook
    which
    isabelle
    mlton
    openjdk_headless
    fontconfig

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

  # TODO the isabelle components part downloads a bunch of stuff
  preBuild = ''
    cd l4v

    mkdir --parent -- "$HOME/.isabelle/etc"
    cp -- misc/etc/settings "$HOME/.isabelle/etc/settings"
    ./isabelle/bin/isabelle components -a
    ./isabelle/bin/isabelle jedit -bf
    ./isabelle/bin/isabelle build -bv HOL

    cd proof
  '';

  buildPhase = ''
    runHook preBuild

    make all

    runHook postBuild
  '';
})
