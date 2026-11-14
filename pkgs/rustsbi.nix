{
  lib,
  buildPackages,
  fetchFromGitHub,
  llvmPackages,
  makeRustPlatform,
  rustPlatform,
  symlinkJoin,
}:
let
  src = fetchFromGitHub {
    owner = "rustsbi";
    repo = "rustsbi";
    rev = "0e0ae20ca3a05865213e0ab715ab2f3f5540b491";
    hash = "sha256-8p0P7olu8S+G66O2FEJf1EIaxNmhgFZBKSQSp/6C4eM=";
  };

  sysroot = symlinkJoin {
    name = "rustc-unwrapped-with-libsrc";
    paths = [ buildPackages.rustc.unwrapped ];
    postBuild = ''
      mkdir --parent -- $out/lib/rustlib/src/rust
      ln --symbolic -- ${rustPlatform.rustLibSrc} $out/lib/rustlib/src/rust/library
    '';
  };

  rustc = buildPackages.rustc.override { inherit sysroot; };

  nixRustPlatform = makeRustPlatform {
    cargo = rustPlatform.cargo;
    inherit rustc;
  };
in
nixRustPlatform.buildRustPackage {
  pname = "rustsbi-riscv64-virt";
  version = "unstable-2026-11-14";
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [ llvmPackages.llvm ];
  doCheck = false;
  env.RUSTC_BOOTSTRAP = "1";
  env.RUST_SRC_PATH = "${rustPlatform.rustLibSrc}";
  env.CARGO_TARGET_DIR = "target";

  buildPhase = ''
    runHook preBuild
    cargo prototyper build --target riscv64gc-unknown-none-elf dynamic
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 \
      target/riscv64gc-unknown-none-elf/release/rustsbi-prototyper-dynamic.elf \
      "$out/share/rustsbi/rustsbi-prototyper-dynamic.elf"
    install -Dm644 \
      target/riscv64gc-unknown-none-elf/release/rustsbi-prototyper-dynamic.bin \
      "$out/share/rustsbi/rustsbi-prototyper-dynamic.bin"
    runHook postInstall
  '';

  meta = {
    description = "RustSBI Prototyper firmware for QEMU virt on RV64";
    homepage = "https://github.com/rustsbi/rustsbi";
    license = with lib.licenses; [ mit mulan-psl2 ];
    platforms = [ "x86_64-linux" ];
  };
}
