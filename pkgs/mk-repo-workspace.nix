{
  lib,
  runCommand,
}:

{
  name,
  projects,
  linkfiles ? [ ],
}:

let
  # Copy directly from flake inputs into $TMPDIR/source during build:
  # - zero duplicate storage in /nix/store
  # - preserves executable (+x) bits on scripts & configure while making files writable
  # - read-only asset repos (symlink = true) skip copying into $TMPDIR altogether
  unpackPhase = ''
    runHook preUnpack
    sourceRoot=source
    mkdir -p "$sourceRoot"
    ${lib.concatMapStringsSep "\n" (
      {
        path,
        src,
        symlink ? false,
      }:
      if symlink then
        ''
          mkdir -p "$sourceRoot/${dirOf path}"
          ln -s "${src}" "$sourceRoot/${path}"
        ''
      else
        ''
          mkdir -p "$sourceRoot/${dirOf path}"
          cp -r --preserve=mode,links "${src}" "$sourceRoot/${path}"
          chmod -R u+w "$sourceRoot/${path}"
        ''
    ) projects}
    ${lib.concatMapStringsSep "\n" (
      { src, dest }:
      ''
        mkdir -p "$sourceRoot/${dirOf dest}"
        ln -s "${src}" "$sourceRoot/${dest}"
      ''
    ) linkfiles}
    runHook postUnpack
  '';
in
# Store only a tiny symlink forest in /nix/store for inspection / direct browsing
(runCommand name { } ''
  mkdir -p "$out"
  ${lib.concatMapStringsSep "\n" (
    { path, src, ... }:
    ''
      mkdir -p "$out/${dirOf path}"
      ln -s "${src}" "$out/${path}"
    ''
  ) projects}
  ${lib.concatMapStringsSep "\n" (
    { src, dest }:
    ''
      mkdir -p "$out/${dirOf dest}"
      ln -s "${src}" "$out/${dest}"
    ''
  ) linkfiles}
'').overrideAttrs
  (_: {
    passthru = {
      inherit unpackPhase projects linkfiles;
    };
  })
