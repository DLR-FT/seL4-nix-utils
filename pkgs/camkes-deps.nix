# Taken from camkes-deps 0.7.4 (https://pypi.org/project/camkes-deps/#files)
{
  cmake-format,
  python3Packages,
}:
(import ./seL4-deps.nix {
  inherit cmake-format python3Packages;
})
++ [
  python3Packages.aenum
  python3Packages.ordered-set
  # orderedset # broken in nixpkgs; for older source trees, removed in 0.7.5
  python3Packages.plyplus
  python3Packages.pycparser
  python3Packages.concurrencytest

  # capDL deps
  python3Packages.sortedcontainers
  python3Packages.hypothesis
]
