{
  aeson,
  array,
  base,
  base-compat,
  bytestring,
  containers,
  filepath,
  lens,
  lib,
  MissingH,
  mkDerivation,
  mtl,
  parsec,
  pretty,
  regex-compat,
  split,
  text,
  unix,
  yaml,
  src,
  version,
}:
mkDerivation {
  pname = "capDL-tool";
  inherit version src;
  postUnpack = "sourceRoot+=/capDL-tool; echo source root reset to $sourceRoot";
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson
    array
    base
    base-compat
    bytestring
    containers
    filepath
    lens
    MissingH
    mtl
    parsec
    pretty
    regex-compat
    split
    text
    unix
    yaml
  ];
  homepage = "https://github.com/seL4/capdl";
  description = "A tool for processing seL4 capDL specifications";
  license = lib.licenses.bsd2;
  mainProgram = "parse-capDL";
  maintainers = [ lib.maintainers.wucke13 ];
}
