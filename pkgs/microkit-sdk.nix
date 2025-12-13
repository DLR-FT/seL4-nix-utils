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

  # Microkit requires the seL4 source to be compiled. Be careful when changing this, each Microkit
  # release is targeting a specific seL4 releases!
  seL4-src ? fetchFromGitHub {
    owner = "seL4";
    repo = "seL4";
    # bespoke commit from microkit developer documentation, taken on 2025-12-11
    # https://github.com/seL4/microkit/blob/2.1.0/DEVELOPER.md#sel4-version
    rev = "14.0.0";
    hash = "sha256-kzRV3qIsfyIFoc2hT6l0cIyR6zLD4yHcPXCAbGAQGsk=";
  },
}:

let

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
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "seL4";
    repo = "microkit";
    rev = finalAttrs.version;
    hash = "sha256-6v54u4f3ktEoHkmGrijHqfaKyqOIK7HLQTnNCWrmSDI=";
  };

  # cargoRoot = "tool/microkit/";
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    sourceRoot = "source/";
    hash = "sha256-o1oJYDo9Bqgn0YopAXAnwqGSKrq1o0hzHFK+xG9kksw=";
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
    pkgsCross.x86_64-embedded.stdenv.cc.bintools.bintools
    pkgsCross.x86_64-embedded.stdenv.cc.cc

    # microkit-sdk dependencies
    cargo
    cmake
    ninja
    pandoc
    rustPlatform.bindgenHook
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
