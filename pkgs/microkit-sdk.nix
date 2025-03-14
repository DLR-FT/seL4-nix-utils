{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pkgsCross,
  dtc,
  cargo,
  cmake,
  libxml2,
  ninja,
  pandoc,
  python3Packages,
  qemu,
  rustc,
  texlive,
}:

let
  # TODO make seL4-src overridable
  seL4-src = fetchFromGitHub {
    owner = "seL4";
    repo = "seL4";
    # bespoke commit from microkit README, taken on 2024-07-02
    # https://github.com/seL4/microkit/tree/1.3.0?tab=readme-ov-file#sel4-version
    rev = "968d8f6f97a37ea315243510348e933b612319f1";
    hash = "sha256-m4PZj+bDWCgGF+LQDLS/Z4thZKAp070TBt8+fpPl5PI=";
  };

  # To debug the required TeX packages:
  #
  # nix-shell --pure --packages '(texlive.combine { inherit (texlive) enumitem environ fontaxes isodate roboto pdfcol scheme-medium sfmath substr tcolorbox titlesec; })' --packages pandoc --run "TEXINPUTS=$(nix eval --raw .\#microkit-sdk.src)/docs/style/: pandoc $(nix eval --raw .\#microkit-sdk.src)/docs/manual.md -o manual.pdf"
  tex = (
    texlive.combine {
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
        titlesec
        ;
    }
  );

  inherit (lib.strings) escapeShellArg removeSuffix;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "microkit-sdk";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "seL4";
    repo = "microkit";
    rev = finalAttrs.version;
    hash = "sha256-bFKD6Sqro2NokTYY25JcyWLYkMWmjdCUOSoeIyuR+YQ=";
  };

  cargoRoot = "tool/microkit/";
  cargoDeps = rustPlatform.fetchCargoTarball {
    inherit (finalAttrs) src;
    sourceRoot = "source/" + finalAttrs.cargoRoot;
    hash = "sha256-bGGD5Gz5UffaCzX4ZL7yIJfKj3D7qU+sqdro4COiiGY=";
  };

  nativeBuildInputs = [
    # cross compiler for seL4 kernel compilation

    # We want the unwrapped cc, Nix usually injects some compiler flags that might collide with
    # seL4's way of building things. However, the unwrapped compiler (stdenv.cc.cc) does not contain
    # bintools, so we have to import them as well.
    pkgsCross.aarch64-embedded.stdenv.cc.bintools.bintools
    pkgsCross.aarch64-embedded.stdenv.cc.cc
    pkgsCross.riscv64-embedded.stdenv.cc.bintools.bintools
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

    (python3Packages.python.withPackages (
      ps: with ps; [
        mypy
        black
        flake8
        ply
        jinja2
        pyyaml
        pyfdt
        lxml
      ]
    ))
  ];
  dontUseCmakeConfigure = true; # the build is driven by build_sdk.py, not cmake

  prePatch = ''
    cp --recursive -- "${seL4-src}" seL4-src
    chmod --recursive -- u+w seL4-src
    patchShebangs seL4-src

    # upstream issue: https://github.com/seL4/microkit/issues/201
    substituteInPlace build_sdk.py --replace-fail riscv64-unknown-elf \
      ${escapeShellArg (removeSuffix "-" pkgsCross.riscv64-embedded.stdenv.cc.targetPrefix)}
  '';

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
