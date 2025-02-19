{
  lib,
  makeRustPlatform,
  stdenv,
  fetchFromGitHub,
  pkgsBuildBuild,
  # User configurable arguments
  src ? null,
  rustToolchainTargets ? null,
  packageToBuild,
  rustTargetPath ? "",
  rustToolchain ? null,
  rustcTarget ? stdenv.targetPlatform.rust.rustcTarget,
  compilerDepsPath ? null,
  compilerDepsHash ? null,
  rustToolchainVersion ? null,
  seL4-kernel,
}:
assert
  !isNull compilerDepsPath
  -> isNull compilerDepsHash
  -> throw "compilerDepsPath requires compilerDepsHash";
assert
  !isNull rustToolchain
  -> !isNull rustToolchainVersion
  -> lib.warn "if rustToolchain is set, rustToolchainVersion does not have any effect" true;
assert
  !isNull rustToolchain
  -> !isNull rustToolchainTargets
  -> lib.warn "if rustToolchain is set, rustToolchainTargets does not have any effect" true;
assert
  isNull rustToolchain
  -> !(pkgsBuildBuild ? rust-bin)
  -> throw "if rustToolchain is not set, the oxalica overlay is required";
assert isNull rustcTarget -> throw "rustcTarget may not be null";
let
  defaultSrc = fetchFromGitHub {
    owner = "seL4";
    repo = "rust-sel4";
    rev = "v1.0.0";
    hash = "sha256-gZOvuq+icY+6MSlGkPVpqpjzOnhx4G83+x9APc+35nE=";
  };
  src' = if isNull src then defaultSrc else src;
  defaultRustToolchainTargets = [ rustcTarget ];
  rustToolchainTargets' =
    if isNull rustToolchainTargets then defaultRustToolchainTargets else rustToolchainTargets;
  rustToolchainVersion' = if isNull rustToolchainVersion then "1.80.0" else rustToolchainVersion;
  defaultToolchain = pkgsBuildBuild.rust-bin.stable.${rustToolchainVersion'}.minimal.override {
    extensions = [ "rust-src" ];
    targets = rustToolchainTargets';
  };
  rustToolchain' = if isNull rustToolchain then defaultToolchain else rustToolchain;
  rustPlatform = makeRustPlatform {
    rustc = rustToolchain';
    cargo = rustToolchain';
  };
  defaultCompilerDepsPath = "${rustToolchain'}/lib/rustlib/src/rust";
  defaultCompilerDepsHash = "sha256-MZdXiyI731xmlddlVpcDemWTDDTX8qovHW+Eesh2fs4=";
  compilerDepsPath' = if isNull compilerDepsPath then defaultCompilerDepsPath else compilerDepsPath;
  compilerDepsHash' = if isNull compilerDepsHash then defaultCompilerDepsHash else compilerDepsHash;
  compilerDeps = rustPlatform.fetchCargoVendor {
    src = compilerDepsPath';
    name = "compiler-deps";
    hash = compilerDepsHash';
  };
  cargoBuildHook = rustPlatform.cargoBuildHook.overrideAttrs (_: {
    rustHostPlatformSpec = rustcTarget; # change to desired rustcTarget
  });
  cargoInstallHook = rustPlatform.cargoInstallHook.overrideAttrs (_: {
    targetSubdirectory = rustcTarget; # change subdirectory to utilized rustcTarget
  });
in
rustPlatform.buildRustPackage {
  name = packageToBuild;
  version = "1.0.0";

  src = src';

  nativeBuildInputs = [ pkgsBuildBuild.rustPlatform.bindgenHook ];

  buildInputs = [
    cargoBuildHook # shadow old cargoBuildHook
    cargoInstallHook # shadow old cargoInstallHook
  ];

  postPatch = ''
    # Link the compiler dependencies into the cargo-vendor-dir, populated by the cargoSetupHook
    # required because we build for a custom rust target *-sel4
    # these compiler deps need to match the rust-src deps of the utilized rust toolchain
    find ${compilerDeps} -mindepth 1 -maxdepth 1 -type d \
      -exec ln -sf {} /build/cargo-vendor-dir/ \;
  '';

  env.SEL4_PREFIX = seL4-kernel;
  env.RUST_TARGET_PATH = rustTargetPath;
  # required to access Zbuild flags
  env.RUSTC_BOOTSTRAP = 1;

  cargoBuildFlags = [
    "--package=${packageToBuild}"
    "-Zbuild-std=core,alloc,compiler_builtins"
    "-Zbuild-std-features=compiler-builtins-mem"
  ];

  doCheck = false;

  cargoLock = {
    lockFile = src + "/Cargo.lock";
    allowBuiltinFetchGit = true;
  };
}
