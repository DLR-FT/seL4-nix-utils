{ stdenv
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
    # bespoke commit from microkit README, taken on 2024-05-30
    rev = "57975d485397ce1744f7163644dd530560d0b7ec";
    hash = "sha256-s+dU0Lo28CHdFhkvKwb56RNJrnsMVIKzglllCzYm5Ww=";
  };

  # microkit docs themselve use only the `titlesec` package. The rest of the dependencies come from pandoc.
  tex = (texlive.combine { inherit (texlive) scheme-gust titlesec; });
in
stdenv.mkDerivation rec {
  pname = "microkit-sdk";
  version = "unstable-2024-05-30";

  src = fetchFromGitHub {
    owner = "seL4";
    repo = "microkit";
    rev = "6f7cafc9563d23aa18fb5776d4acb087873a9d28";
    hash = "sha256-zAKjXLCdCbwC5H32mXKfuAtHvXSe466q+m19wnK0gys=";
  };

  cargoRoot = "tool/microkit/";
  cargoDeps = rustPlatform.importCargoLock {
    lockFile = src + "/" + cargoRoot + "Cargo.lock";
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
}
