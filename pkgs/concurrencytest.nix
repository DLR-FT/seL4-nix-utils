{
  lib,
  buildPythonPackage,
  setuptools,
  subunit,
  testtools,
  src,
  version,
}:

buildPythonPackage {
  pname = "concurrencytest";
  inherit version src;

  pythonRelaxDeps = [ "testtools" ];

  propagatedBuildInputs = [
    subunit
    testtools
  ];

  pythonImportsCheck = [
    "time"
    "unittest"
    "concurrencytest"
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
