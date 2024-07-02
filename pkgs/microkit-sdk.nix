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
    rev = "0cdbffec9cf6b4c7c9c57971cbee5a24a70c8fd0";
    hash = "sha256-avBeo3kwv08b263umMf6kMtiWgpieT0+vOTGjvnqQgk=";
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
in
stdenv.mkDerivation rec {
  pname = "microkit-sdk";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "seL4";
    repo = "microkit";
    rev = version;
    hash = "sha256-gIGlLPAEZ+eJ9TU8B8POAeS2gf/C+R+MjT24zN57R0k=";
  };

  cargoRoot = "tool/microkit/";
  cargoDeps = rustPlatform.fetchCargoTarball {
    inherit src;
    sourceRoot = "source/" + cargoRoot;
    hash = "sha256-+IfOFMGz9dz4L1uE4zJ+K2/nW9Q7+prJqYCZSN9P2ZY=";
  };

  nativeBuildInputs = [
    # cross compiler for seL4 kernel compilation

    # We want the unwrapped cc, Nix usually injects some compiler flags that might collide with
    # seL4's way of building things. However, the unwrapped compiler (stdenv.cc.cc) does not contain
    # bintools, so we have to import them as well.
    pkgsCross.aarch64-embedded.stdenv.cc.cc
    pkgsCross.riscv64-embedded.stdenv.cc.cc
    pkgsCross.aarch64-embedded.stdenv.cc.bintools
    pkgsCross.riscv64-embedded.stdenv.cc.bintools

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

  postPatch = ''
    cp --recursive -- "${seL4-src}" seL4-src
    chmod --recursive -- u+w seL4-src
    patchShebangs seL4-src
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
}
