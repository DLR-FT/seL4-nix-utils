{ buildPythonPackage, fetchFromGitHub, camkes-deps }:

buildPythonPackage rec {
  name = "camkes-tool";
  version = "3.11.0";
  src = fetchFromGitHub {
    owner = "seL4";
    repo = "camkes-tool";
    rev = "camkes-" + version;
    hash = "";
  };

  propagatedBuildInputs = [ camkes-deps ];
}

