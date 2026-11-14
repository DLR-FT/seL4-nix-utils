{ lib, inputs }:
let
  revTag = src: if src ? shortRev then src.shortRev else "dirty";

  readTrimmed =
    path: fallback:
    if builtins.pathExists path then lib.strings.trim (builtins.readFile path) else fallback;

  readCabalVersion =
    path: fallback:
    if builtins.pathExists path then
      let
        m = builtins.match ".*\nversion:[[:space:]]*([0-9][^\r\n]*).*" (builtins.readFile path);
      in
      if m != null then lib.strings.trim (builtins.head m) else fallback
    else
      fallback;

  readSetupPyVersion =
    path: fallback:
    if builtins.pathExists path then
      let
        m = builtins.match ".*version[[:space:]]*=[[:space:]]*'([^']+)'.*" (builtins.readFile path);
      in
      if m != null then builtins.head m else fallback
    else
      fallback;

  readPyprojectVersion =
    path: fallback:
    if builtins.pathExists path then
      (fromTOML (builtins.readFile path)).project.version or fallback
    else
      fallback;
in
{
  seL4 = readTrimmed "${inputs.seL4-src}/VERSION" "0.0.0-${revTag inputs.seL4-src}";

  capDL-tool = readCabalVersion "${inputs.capdl-src}/capDL-tool/capDL-tool.cabal" "0.0.0-${revTag inputs.capdl-src}";

  camkes = lib.strings.removePrefix "camkes-" (
    readTrimmed "${inputs.camkes-tool-src}/VERSION" "0.0.0-${revTag inputs.camkes-tool-src}"
  );

  microkit = readTrimmed "${inputs.microkit-src}/VERSION" "0.0.0-${revTag inputs.microkit-src}";
  microkitCargoOutputHashes = {
    "sel4-capdl-initializer-0.1.0" = "sha256-hp5aHxAqUuThMcPSZ+wh+4yPIgPdzl9Xtk+VL1RkxiM=";
  };

  guardonce = readSetupPyVersion "${inputs.guardonce-src}/setup.py" "0.0.0-${revTag inputs.guardonce-src}";
  concurrencytest = readPyprojectVersion "${inputs.concurrencytest-src}/pyproject.toml" "0.0.0-${revTag inputs.concurrencytest-src}";

  xilinx-embeddedsw = "2026.2";
  xilinx-atf = "xilinx-v2026.1";
  xilinx-uboot = "xilinx-v2026.1";
  opensbi = "1.9";
}
