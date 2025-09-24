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
    sha256 = "sha256-1LI9ewSoKzPSuD0DOJWxECbR9Fy7GbwHgTIn/SDEtHg=";
    rev = "9d4ca9a9c2cbd1aaa759cd7ea59bf7e0f65437bd";
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
