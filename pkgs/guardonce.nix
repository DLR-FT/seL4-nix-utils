{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pip,
}:

buildPythonPackage rec {
  pname = "guardonce";
  version = "2.4.0";

  src = fetchFromGitHub {
    owner = "cgmb";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-yTywLxvo6R02svdfHx5iP5njFUTWdhnwNXN6BNIbyR8=";
  };

  # TODO investigate why some test fais in the nose code with
  #  AttributeError: module 'collections' has no attribute 'Sequence'
  doCheck = false;
  preBuild = ''
    export HOME="$(mktemp --directory)"
  '';

  propagatedBuildInputs = [ pip ];

  meta = with lib; {
    description = "Utilities for converting from C/C++ include guards to #pragma once and back again";
    homepage = "https://github.com/cgmb/guardonce";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ wucke13 ];
  };
}
