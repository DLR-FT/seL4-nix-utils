{
  fetchFromGitHub,
  packageToBuild,
  makeRustPlatform,
  pkgsBuildTarget,
  rustToolchain ? null,
}:
assert
  isNull rustToolchain
  -> !(pkgsBuildTarget ? rust-bin)
  -> throw "if rustToolchain is not set, the oxalica overlay is required";
let
  defaultRustToolchain = pkgsBuildTarget.rust-bin.stable.latest.minimal;
  rustToolchain' = if isNull rustToolchain then defaultRustToolchain else rustToolchain;
  rustPlatform = makeRustPlatform {
    rustc = rustToolchain';
    cargo = rustToolchain';
  };
in
rustPlatform.buildRustPackage rec {
  name = packageToBuild;
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "seL4";
    repo = "rust-sel4";
    rev = "v${version}";
    hash = "sha256-gZOvuq+icY+6MSlGkPVpqpjzOnhx4G83+x9APc+35nE=";
  };

  cargoBuildFlags = [ "--package=${packageToBuild}" ];

  env.RUSTC_BOOTSTRAP = 1;

  doCheck = false;

  cargoLock = {
    lockFile = src + "/Cargo.lock";
    allowBuiltinFetchGit = true;
  };
}
