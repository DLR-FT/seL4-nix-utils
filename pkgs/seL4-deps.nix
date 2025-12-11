{
  lib,
  buildPythonPackage,
  six,
  jinja2,
  lxml,
  ply,
  psutil,
  beautifulsoup4,
  pyelftools,
  sh,
  pexpect,
  pyaml,
  jsonschema,
  pyfdt,
  cmake-format,
  guardonce,
  autopep8,
  libarchive-c,
  setuptools,
}:

buildPythonPackage {
  pname = "sel4-deps";
  version = "0.7.0";

  dontUnpack = true;
  dontBuild = true;
  format = "other"; # don't actually try to install anything

  propagatedBuildInputs = [
    # taken of sel-deps 0.7.0 on 2025-09-24
    # https://pypi.org/project/sel4-deps/#files
    six
    jinja2
    lxml
    ply
    psutil
    beautifulsoup4 # referenced as bs4, but upstream says one shall not use that alias
    pyelftools
    sh
    pexpect
    pyaml
    jsonschema
    pyfdt
    cmake-format
    guardonce
    autopep8
    libarchive-c

    # Not in the seL4-deps, but still required
    setuptools # otherwise: ModuleNotFoundError: No module named 'pkg_resources'
  ];

  meta = with lib; {
    description = "Metapackage for downloading build dependencies for the seL4 microkernel";
    homepage = "https://sel4.systems/";
    license = with licenses; [ bsd2 ];
    maintainers = with maintainers; [ wucke13 ];
  };
}
