{
  fetchFromGitHub,
  makeRustPlatform,
  rustPlatform,
  # User configurable arguments
  rustToolchain ? null,
  packageToBuild,
}:
let
  rustPlatform' =
    if isNull rustToolchain then
      rustPlatform
    else
      makeRustPlatform {
        rustc = rustToolchain;
        cargo = rustToolchain;
      };
in
rustPlatform'.buildRustPackage rec {
  name = packageToBuild;
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "seL4";
    repo = "rust-sel4";
    rev = "v${version}";
    hash = "sha256-gZOvuq+icY+6MSlGkPVpqpjzOnhx4G83+x9APc+35nE=";
  };

  cargoBuildFlags = [ "--package=${packageToBuild}" ];

  # somtimes required to access nightly features
  env.RUSTC_BOOTSTRAP = 1;

  doCheck = false;

  cargoLock = {
    lockFile = src + "/Cargo.lock";
    allowBuiltinFetchGit = true;
  };
}
