{ lib, buildPythonPackage, aenum, jinja2, ordered-set, plyplus, pyelftools
, seL4-deps, pycparser, pyfdt, concurrencytest, sortedcontainers, hypothesis }:

buildPythonPackage rec {
  pname = "camkes-deps";
  version = "0.7.3";

  dontUnpack = true;
  dontBuild = true;
  format = "other"; # don't actually try to install anything

  propagatedBuildInputs = [
    # taken of camkes-deps 0.7.3 on 2024-02-11
    # https://pypi.org/project/camkes-deps/#files
    aenum
    jinja2
    ordered-set
    # this package is marked broken in nixpkgs and due for removal anyways
    #orderedset # For older source trees: remove in 0.7.4
    plyplus
    pyelftools
    seL4-deps
    pycparser
    pyfdt
    concurrencytest
    # capDL deps
    sortedcontainers
    hypothesis
  ];

  meta = with lib; {
    description = "Metapackage for downloading build dependencies for CAmkES";
    homepage = "https://docs.sel4.systems/CAmkES/";
    license = with licenses; [ bsd2 ];
    maintainers = with maintainers; [ wucke13 ];
  };
}
