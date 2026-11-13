{
  lib,
  buildPythonPackage,
  pip,
  setuptools,
  src,
  version,
}:

buildPythonPackage {
  pname = "guardonce";
  inherit version src;

  # TODO investigate why some test fais in the nose code with
  #  AttributeError: module 'collections' has no attribute 'Sequence'
  doCheck = false;
  preBuild = ''
    export HOME="$(mktemp --directory)"
  '';
  pyproject = true;
  build-system = [ setuptools ];

  propagatedBuildInputs = [ pip ];

  meta = with lib; {
    description = "Utilities for converting from C/C++ include guards to #pragma once and back again";
    homepage = "https://github.com/cgmb/guardonce";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ wucke13 ];
  };
}
