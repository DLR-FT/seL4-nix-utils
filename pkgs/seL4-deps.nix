# Taken from sel4-deps 0.7.0 (https://pypi.org/project/sel4-deps/#files)
{
  cmake-format,
  python3Packages,
}:
[
  python3Packages.six
  python3Packages.jinja2
  python3Packages.lxml
  python3Packages.ply
  python3Packages.psutil
  python3Packages.beautifulsoup4 # referenced as bs4, but upstream says one shall not use that alias
  python3Packages.pyelftools
  python3Packages.sh
  python3Packages.pexpect
  python3Packages.pyaml
  python3Packages.jsonschema
  python3Packages.pyfdt
  cmake-format
  python3Packages.guardonce
  python3Packages.autopep8
  python3Packages.libarchive-c

  # Not in seL4-deps, but still required
  python3Packages.setuptools # otherwise: ModuleNotFoundError: No module named 'pkg_resources'
]
