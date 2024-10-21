{ fetchFromGitHub, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "sel4-kernel-loader";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "seL4";
    repo = "rust-sel4";
    rev = "v${version}";
    hash = "sha256-gZOvuq+icY+6MSlGkPVpqpjzOnhx4G83+x9APc+35nE=";
  };

  cargoHash = "";
  cargoBuildFlags = [ "--package=${pname}" ];
}
