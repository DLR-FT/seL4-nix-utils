{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  python-subunit,
  testtools,
}:

buildPythonPackage rec {
  pname = "concurrencytest";
  version = "0.1.2";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-ZKnFtc25lJo3X8xeEUqCGA9qB8waAm05ViMK7PmAwtg=";
  };

  propagatedBuildInputs = [
    python-subunit
    testtools
  ];

  pythonImportsCheck = [
    "time"
    "unittest"
    # TODO investigate why this can not be imported
    # "concurrencytest.ConcurrentTestSuite"
    # "concurrencytest.fork_for_tests"
  ];

  pyproject = true;
  build-system = [ setuptools ];

  meta = with lib; {
    description = "testtools extension for running unittest suites concurrently";
    homepage = "https://github.com/cgoldberg/concurrencytest";
    license = with licenses; [ gpl3 ];
    maintainers = with maintainers; [ wucke13 ];
  };
}
