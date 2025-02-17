{
  lib,
  rustPlatform,
  stdenv,
  fetchFromGitHub,
  seL4-kernel ? "",
  packageToBuild ? "sel4-kernel-loader-add-payload",
}:

# check that a valid package is selected
# assert
# lib.asserts.assertOneOf "packageToBuild" packageToBuild
#   [
#     "sel4-kernel-loader"
#     "sel4-kernel-loader-add-payload"
#   ]

# check that the seL4-kernel is specified when building the loader itself
assert
  (packageToBuild == "sel4-kernel-loader")
  -> lib.strings.isPath seL4-kernel || lib.attrsets.isDerivation seL4-kernel;

rustPlatform.buildRustPackage rec {
  name = "seL4-kernel-loader";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "seL4";
    repo = "rust-sel4";
    rev = "v${version}";
    hash = "sha256-gZOvuq+icY+6MSlGkPVpqpjzOnhx4G83+x9APc+35nE=";
  };

  env.RUSTC_BOOTSTRAP = 1; # enable the use of nightly features
  env.BOOTSTRAP_SKIP_TARGET_SANITY = 1; # silence the check for custom checks
  env.SEL4_PREFIX = seL4-kernel; # required when buildin the loader itself
  env.CARGO_BUILD_TARGET = rustPlatform.platform.cargoEnvVarTarget;

  postPatch = ''
    substituteInPlace crates/sel4-kernel-loader/build.rs --replace-fail "--image-base" "--Ttext"
    substituteInPlace crates/sel4-kernel-loader/build.rs --replace-fail "println!(\"cargo:rustc-link-arg=--no-rosegment\");" ""
  '';

  cargoBuildFlags =
    [
      "--package=${packageToBuild}"
    ]
    ++ lib.lists.optionals (packageToBuild == "sel4-kernel-loader") [
      "--config"
      ''target.${stdenv.targetPlatform.rust.rustcTarget}.linker="${stdenv.cc.targetPrefix}ld"''
    ];

  doCheck = false;

  cargoLock = {
    lockFile = src + "/Cargo.lock";
    allowBuiltinFetchGit = true;
  };
}
