{
  lib,
  stdenv,
  pkgsCross,
  rustPlatform,
  symlinkJoin,
  buildPackages,
  cargo,
  cmake,
  dtc,
  libxml2,
  ninja,
  pandoc,
  python3Packages,
  qemu,
  texlive,

  # Microkit requires the seL4 source to be compiled. Be careful when changing this, each Microkit
  # release is targeting a specific seL4 releases!
  src,
  seL4-src,
  version,
  cargoHash,
}:

let
  # To debug the required TeX packages:
  #
  # nix-shell --pure --packages '(texlive.combine { inherit (texlive) enumitem environ fontaxes isodate roboto pdfcol scheme-medium sfmath substr tcolorbox titlesec; })' --packages pandoc --run "TEXINPUTS=$(nix eval --raw .\#microkit-sdk.src)/docs/style/: pandoc $(nix eval --raw .\#microkit-sdk.src)/docs/manual.md -o manual.pdf"
  texEnv = (
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

  # With version 2.1.0, Microkit switches to `rust-sel4` based initialization. Unfortunately, this
  # requires nightly features, in particular custom targets. In addition, that implicates that
  # rust-src must be available (which isn't the case in nixpkgs' rustc). To work around this, we
  # generate a rustc wrapped with a rust-src so that the building works.
  sysroot = symlinkJoin {
    name = "rustc_unwrapped_with_libsrc";
    paths = [ buildPackages.rustc.unwrapped ];
    postBuild = ''
      mkdir --parent -- $out/lib/rustlib/src/rust
      ln --symbolic -- ${rustPlatform.rustLibSrc} $out/lib/rustlib/src/rust/library
    '';
  };

  rustc = buildPackages.rustc.override { inherit sysroot; };

  rustLldFake = buildPackages.runCommand "rust-lld-fake" { } ''
    mkdir --parent -- $out/bin
    ln --symbolic -- ${lib.meta.getExe' buildPackages.rustc.llvmPackages.lld "lld"} $out/bin/lld
    ln --symbolic -- ${lib.meta.getExe' buildPackages.rustc.llvmPackages.lld "lld"} $out/bin/rust-lld
  '';

  inherit (lib.strings) escapeShellArg removeSuffix;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "microkit-sdk";
  inherit version src;

  cargoDeps = symlinkJoin {
    name = "microkit-cargodeps";
    paths = [
      (rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) src;
        sourceRoot = "source/";
        hash = cargoHash;
      })
    ];
    # Add rust-src so that -Zbuild-std works
    postBuild = ''
      cp --no-clobber --recursive --symbolic-link ${rustPlatform.rustVendorSrc}/* $out/source-registry-0/
    '';
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
    qemu
    rustLldFake # required for the build-std using rust-sel4 crates
    rustPlatform.bindgenHook
    rustPlatform.cargoSetupHook
    rustc
    texEnv

    # seL4 dependencies
    dtc
    libxml2 # for xmllint

    (python3Packages.python.withPackages (
      ps: with ps; [
        black
        flake8
        jinja2
        jsonschema
        lxml
        mypy
        ply
        pyfdt
        pyyaml
      ]
    ))
  ];
  dontUseCmakeConfigure = true; # the build is driven by build_sdk.py, not CMake

  prePatch = ''
    cp --recursive -- "${seL4-src}" seL4-src
    chmod --recursive -- u+w seL4-src
    patchShebangs seL4-src
  '';

  postPatch = ''
    substituteInPlace build_sdk.py \
      --replace-fail "-p initialiser" "-Z build-std=core,alloc -p initialiser"
  '';

  env.RUSTC_BOOTSTRAP = "1";

  buildPhase = ''
    runHook preBuild
    python build_sdk.py --sel4=seL4-src \
      --skip-tar \
      --tool-target-triple=${stdenv.hostPlatform.rust.rustcTarget} \
      --gcc-toolchain-prefix-aarch64=${escapeShellArg (removeSuffix "-" pkgsCross.aarch64-embedded.stdenv.cc.targetPrefix)} \
      --gcc-toolchain-prefix-riscv64=${escapeShellArg (removeSuffix "-" pkgsCross.riscv64-embedded.stdenv.cc.targetPrefix)} \
      --gcc-toolchain-prefix-x86_64=${escapeShellArg (removeSuffix "-" pkgsCross.x86_64-embedded.stdenv.cc.targetPrefix)}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mv release/microkit-sdk*/ $out/
    runHook postInstall
  '';

  passthru = {
    inherit
      seL4-src
      rustc
      rustLldFake
      texEnv
      ;
  };

  meta = {
    description = "An SDK to enable system designers to create static software systems based on the seL4 microkernel";
    homepage = "https://trustworthy.systems/projects/microkit/";
    license = lib.licenses.bsd2;
    maintainers = with lib.maintainers; [ wucke13 ];
    platforms = with lib.platforms; unix;
  };
})
