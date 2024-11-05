{ lib, fetchFromGitHub, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "sel4-kernel-loader";
  version = "1.0.0";
  src = fetchFromGitHub {
    owner = "seL4";
    repo = "rust-sel4";
    rev = "v${version}";
    hash = "sha256-gZOvuq+icY+6MSlGkPVpqpjzOnhx4G83+x9APc+35nE=";
  };

  cargoSha256 = "";
  cargoFlags = [ "--package=${pname}" ];
  cargoLock = {
    lockFile = src + "/Cargo.lock";
    outputHashes = {
      "builtin-0.1.0" = "sha256-cUazPRx6fBWHf1pGBOImEs4lAbbFWkz2jbu9CF2I0K4=";
      "dafny_runtime-0.1.0" = "sha256-f+J8HY0WgR6HqP4gx4ZY4EZYvSmdJ7tryz1cevg4BX8=";
      "embedded-fat-0.5.0" = "sha256-esngsrf43XqbqgzbbJCFtlPReatZbWN4HXJGwCxt6jg=";
      "ring-0.17.8" = "sha256-CKO08q7UJt8nmZiEUC88RxUrubFkI5cFvICAbqgwZMA=";
      "volatile-0.5.1" = "sha256-eUFk+46/ghZufo2YkK4JGW60eN03tlNhKm/G0Xlxia0=";
    };
  };

  meta = {
    platforms = lib.platforms.all;
  };
}
