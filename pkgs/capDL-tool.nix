{
  mkDerivation,
  array,
  base,
  base-compat,
  containers,
  fetchgit,
  filepath,
  lens,
  lib,
  MissingH,
  mtl,
  parsec,
  pretty,
  regex-compat,
  split,
  unix,
  yaml,
}:
mkDerivation {
  pname = "capDL-tool";
  version = "1.0.0.1";
  src = fetchgit {
    url = "https://github.com/seL4/capdl.git";
    sha256 = "1mmmq3qqqwcd1mjhh1la5azwmy6ywskj38lfml0krrlcksqx2aq2";
    rev = "852bc9864fcb2d45e0aaa05f80b2d60c689f74f8";
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
