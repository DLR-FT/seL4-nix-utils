{
  fetchFromGitHub,
  makeRustPlatform,
  rustPlatform,
  # User configurable arguments
  rust-sel4 ? null,
  rustToolchain ? null,
  packageToBuild,
}:
let
  defaultRustSeL4 = fetchFromGitHub {
    owner = "seL4";
    repo = "rust-sel4";
    rev = "v1.0.0";
    hash = "sha256-gZOvuq+icY+6MSlGkPVpqpjzOnhx4G83+x9APc+35nE=";
  };
  rustSeL4 = if isNull rust-sel4 then defaultRustSeL4 else rust-sel4;
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

  src = rustSeL4;

  cargoBuildFlags = [ "--package=${packageToBuild}" ];

  # somtimes required to access nightly features
  env.RUSTC_BOOTSTRAP = 1;

  doCheck = false;

  cargoLock = {
    lockFile = src + "/Cargo.lock";
    allowBuiltinFetchGit = true;
  };
}
