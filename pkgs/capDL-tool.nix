{ mkDerivation, array, base, base-compat, containers, fetchgit, filepath, lens
, lib, MissingH, mtl, parsec, pretty, regex-compat, split, unix, yaml }:
mkDerivation {
  pname = "capDL-tool";
  version = "1.0.0.1";
  src = fetchgit {
    url = "https://github.com/seL4/capdl.git";
    sha256 = "06i3b29l20yi7gdvqsc1a65sjbjavlyps46dj2rwwhk0lb0700b2";
    rev = "f7ef9ca4f9d3e1a8e86375deaf286a056698b9ce";
    fetchSubmodules = false;
  };
  postUnpack = "sourceRoot+=/capDL-tool; echo source root reset to $sourceRoot";
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    array
    base
    base-compat
    containers
    filepath
    lens
    MissingH
    mtl
    parsec
    pretty
    regex-compat
    split
    unix
    yaml
  ];
  homepage = "https://github.com/seL4/capdl";
  description = "A tool for processing seL4 capDL specifications";
  license = lib.licenses.bsd2;
  mainProgram = "parse-capDL";
  maintainers = [ lib.maintainers.wucke13 ];
}
