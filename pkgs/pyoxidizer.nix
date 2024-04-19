{ lib, fetchFromGitHub, rustPlatform, pythonPackages }:

rustPlatform.buildRustPackage rec {
  pname = "pyoxidizer";
  version = "0.24.0";

  src = fetchFromGitHub {
    owner = "indygreg";
    repo = "PyOxidizer";
    rev = "pyoxidizer/${version}";
    hash = "sha256-SD+e3ufgkNvvvy0JTL+UPo8VRVZiN64W3NuChjhfr6Y=";
  };
  cargoHash = "sha256-0f3RKd1LpE/fN0Lhn0lzrWUkOjDFkyGQy/zrMZ6JCck=";

  nativeBuildInputs = [
    pythonPackages.pip
    pythonPackages.setuptools
    pythonPackages.wheel
  ];

  # build python wheel
  postBuild = ''
    ${pythonPackages.python.pythonOnBuildForHost.interpreter} -m pip wheel --verbose --no-index --no-deps --no-clean --no-build-isolation --wheel-dir dist .
  '';

  # install python wheel
  postInstall = ''
    ${pythonPackages.python.pythonOnBuildForHost.interpreter} -m pip install --no-build-isolation --no-index --prefix=$out  --ignore-installed --no-dependencies --no-cache dist/*.whl
  '';

  # TODO investigate test failure:
  #
  #      Running unittests src/lib.rs (target/x86_64-unknown-linux-gnu/release/deps/pyembed-b2e35d9e976473e8)
  # running 59 tests
  # test config::tests::test_packed_resources_implicit_origin ... ok
  # test config::tests::test_packed_resources_explicit_origin ... ok
  # test test::importer::find_spec_missing ... FAILED
  # test test::importer::importer_resource_reading_py ... FAILED
  # test test::importer::importer_pkg_resources_py ... FAILED
  # test test::importer::importer_iter_modules_py ... FAILED
  # test test::importer::builtins_py ... FAILED
  # test test::importer::importer_path_entry_finder_py ... FAILED
  # test test::importer::importer_metadata_py ... FAILED
  # test test::importer::importer_indexing ... FAILED
  # test test::importer::importer_module_py ... FAILED
  # test test::importer::importer_resource_collector_py ... FAILED
  # test test::importer::importer_construction_py ... FAILED
  # test test::importer::importer_module_loading_py ... FAILED
  # test test::interpreter_config::test_allocator_debug ... ok
  # test test::interpreter_config::test_allocator_default ... ok
  # test test::interpreter_config::test_allocator_debug_custom_backend ... ok
  # test test::interpreter_config::test_allocator_rust_pymalloc_arena ... ok
  # test test::interpreter_config::test_argv_override ... ok
  # test test::interpreter_config::test_argv_default ... ok
  # test test::interpreter_config::test_argv_respect_interpreter_config ... ok
  # test test::interpreter_config::test_allocator_rust ... ok
  # test test::interpreter_config::test_argv_utf8 ... ok
  # test test::interpreter_config::test_argvb_utf8 ... ok
  # test test::interpreter_config::test_argv_utf8_isolated_configure_locale ... FAILED
  # test test::interpreter_config::test_argv_utf8_isolated ... ok
  # test test::interpreter_config::test_bytes_warning_raise ... ok
  # test test::interpreter_config::test_bytes_warning_warn ... ok
  # test test::interpreter_config::test_default_interpreter ... ok
  # test test::interpreter_config::test_importer_filesystem ... ok
  # test test::interpreter_config::test_dev_mode ... ok
  # test test::interpreter_config::test_inspect ... ok
  # test test::interpreter_config::test_importer_neither ... ok
  # test test::interpreter_config::test_isolated_interpreter ... ok
  # test test::interpreter_config::test_interactive ... ok
  # test test::interpreter_config::test_optimization_level_one ... ok
  # test test::interpreter_config::test_sys_paths_origin ... ok
  # test test::interpreter_config::test_tcl_library_origin ... ok
  # test test::interpreter_config::test_quiet ... ok
  # test test::interpreter_config::test_site_import_false ... ok
  # test test::interpreter_config::test_optimization_level_two ... ok
  # test test::interpreter_config::test_use_environment ... ok
  # test test::interpreter_config::test_user_site_directory_false ... ok
  # test test::interpreter_config::test_site_import_true ... ok
  # test test::interpreter_config::test_utf8_mode ... ok
  # test test::interpreter_config::test_user_site_directory_true ... FAILED
  # error: test failed, to rerun pass `-p pyembed --lib`
  # Caused by:
  #   process didn't exit successfully: `/build/source/target/x86_64-unknown-linux-gnu/release/deps/pyembed-b2e35d9e976473e8 --test-threads=12` (signal: 11, SIGSEGV: invalid memory reference)
  doCheck = false;

  meta = with lib; {
    description = "A modern Python application packaging and distribution tool";
    homepage = "https://github.com/indygreg/PyOxidizer";
    license = with licenses; [ mpl20 ];
    maintainers = with maintainers; [ wucke13 ];
  };
}
