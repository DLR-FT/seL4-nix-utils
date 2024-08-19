{ lib
, stdenv
, fetchFromGitHub
, rustPlatform
, pkgsCross
, dtc
, cargo
, cmake
, libxml2
, ninja
, pandoc
, python3Packages
, qemu
, rustc
, texlive
}:

let
  # TODO make seL4-src overridable
  seL4-src = fetchFromGitHub {
    owner = "seL4";
    repo = "seL4";
    # bespoke commit from microkit README, taken on 2024-07-02
    # https://github.com/seL4/microkit/tree/1.3.0?tab=readme-ov-file#sel4-version
    rev = "4cae30a6ef166a378d4d23697b00106ce7e4e76f";
    hash = "sha256-9rOVhq0k3K3E62DkUkw+cNAGMVd+agmrm5heRrdfPCw=";
  };

  # To debug the required TeX packages:
  #
  # nix-shell --pure --packages '(texlive.combine { inherit (texlive) enumitem environ fontaxes isodate roboto pdfcol scheme-medium sfmath substr tcolorbox titlesec; })' --packages pandoc --run "TEXINPUTS=$(nix eval --raw .\#microkit-sdk.src)/docs/style/: pandoc $(nix eval --raw .\#microkit-sdk.src)/docs/manual.md -o manual.pdf"
  tex = (texlive.combine {
    inherit (texlive)
      enumitem
      environ
      fontaxes
      isodate
      pdfcol
      roboto
      scheme-medium
      sfmath
      substr
      tcolorbox
      titlesec;
  });

  inherit (lib.strings) escapeShellArg;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "microkit-sdk";
  version = "1.4.1";

  src = fetchFromGitHub {
    owner = "seL4";
    repo = "microkit";
    rev = finalAttrs.version;
    hash = "sha256-eTZ+6vG10ySqeGBcrvwzcITdmujwKF6Hllr+XSpmOgI=";
  };

  cargoRoot = "tool/microkit/";
  cargoDeps = rustPlatform.fetchCargoTarball {
    inherit (finalAttrs) src;
    sourceRoot = "source/" + finalAttrs.cargoRoot;
    hash = "sha256-R5YeQdmPR9tphDBXMB7B//gpr+YuNrvtmrT99fWIqHU=";
  };

  nativeBuildInputs = [
    # cross compiler for seL4 kernel compilation

    # We want the unwrapped cc, Nix usually injects some compiler flags that might collide with
    # seL4's way of building things. However, the unwrapped compiler (stdenv.cc.cc) does not contain
    # bintools, so we have to import them as well.
    pkgsCross.aarch64-embedded.stdenv.cc.bintools
    pkgsCross.aarch64-embedded.stdenv.cc.cc
    pkgsCross.riscv64-embedded.stdenv.cc.bintools
    pkgsCross.riscv64-embedded.stdenv.cc.cc

    # microkit-sdk dependencies
    cargo
    cmake
    ninja
    pandoc
    rustPlatform.cargoSetupHook
    qemu
    rustc
    tex

    # seL4 dependencies
    dtc
    libxml2 # xmllint

    (python3Packages.python.withPackages (ps: with ps; [
      mypy
      black
      flake8
      ply
      jinja2
      pyyaml
      pyfdt
      lxml
    ]))
  ];
  dontUseCmakeConfigure = true; # the build is driven by build_sdk.py, not cmake

  prePatch = ''
    cp --recursive -- "${seL4-src}" seL4-src
    chmod --recursive -- u+w seL4-src
    patchShebangs seL4-src

    # upstream issue: https://github.com/seL4/microkit/issues/201
    substituteInPlace build_sdk.py --replace "riscv64-unknown-elf-" \
      ${escapeShellArg pkgsCross.riscv64-embedded.stdenv.cc.targetPrefix}
  '';

  patches = [
    # upstream PR: https://github.com/seL4/seL4/pull/1310
    # relevant issue: https://github.com/seL4/microkit/issues/201
    ../patches/seL4-riscv-toolchain-prefix.patch
  ];

  buildPhase = ''
    runHook preInstall
    python build_sdk.py --sel4=seL4-src --tool-target-triple=${stdenv.hostPlatform.rust.rustcTarget}
    runHook postInstall
  '';

  installPhase = ''
    runHook preInstall
    mv release/microkit-sdk*/ $out/
    runHook postInstall
  '';

  meta = {
    description = "An SDK to enable system designers to create static software systems based on the seL4 microkernel";
    homepage = "https://trustworthy.systems/projects/microkit/";
    license = lib.licenses.bsd2;
    maintainers = with lib.maintainers; [ wucke13 ];
    platforms = with lib.platforms; unix;
  };
})
