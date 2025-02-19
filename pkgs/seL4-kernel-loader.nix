{
  makeRustPlatform,
  stdenv,
  fetchFromGitHub,
  pkgsBuildBuild,
  # User configurable arguments
  rustToolchain ? null,
  rustcTarget ? stdenv.targetPlatform.rust.rustcTarget,
  seL4-kernel,
}:
assert
  isNull rustToolchain
  -> !(pkgsBuildBuild ? rust-bin)
  -> throw "if rustToolchain is null, the oxalica overlay is required";
assert isNull rustcTarget -> throw "rustcTarget may not be null";
let
  defaultRustToolchain = pkgsBuildBuild.rust-bin.stable.latest.minimal.override {
    targets = [ rustcTarget ];
  };
  rustToolchain' = if isNull rustToolchain then defaultRustToolchain else rustToolchain;
  rustPlatform = makeRustPlatform {
    rustc = rustToolchain';
    cargo = rustToolchain';
  };
  cargoBuildHook = rustPlatform.cargoBuildHook.overrideAttrs (_: {
    rustHostPlatformSpec = rustcTarget; # change to desired rustcTarget
  });
  cargoInstallHook = rustPlatform.cargoInstallHook.overrideAttrs (_: {
    targetSubdirectory = rustcTarget; # change subdirectory to utilized rustcTarget
  });
in

rustPlatform.buildRustPackage rec {
  name = "seL4-kernel-loader";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "seL4";
    repo = "rust-sel4";
    rev = "v${version}";
    hash = "sha256-gZOvuq+icY+6MSlGkPVpqpjzOnhx4G83+x9APc+35nE=";
  };

  buildInputs = [
    cargoBuildHook # shadow old cargoBuildHook
    cargoInstallHook # shadow old cargoInstallHook
  ];

  env.SEL4_PREFIX = seL4-kernel;

  cargoBuildFlags = [ "--package=sel4-kernel-loader" ];

  doCheck = false;

  cargoLock = {
    lockFile = src + "/Cargo.lock";
    allowBuiltinFetchGit = true;
  };
}
