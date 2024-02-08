{ lib, buildPythonPackage, fetchFromGitHub }:

buildPythonPackage rec {
  pname = "pyfdt";
  version = "0.3";
  src = fetchFromGitHub {
    owner = "superna9999";
    repo = pname;
    rev = "${pname}-${version}";
    hash = "sha256-lt/Mcw3j1aTBVOVhDBSYtriDyzeJHcSli69EXLfsgDM=";
  };

  meta = with lib; {
    description = "Python Flattened Device Tree Library";
    homepage = "https://github.com/superna9999/pyfdt";
    license = with licenses; [ asl20 ];
    maintainers = with maintainers; [ wucke13 ];
  };
}
