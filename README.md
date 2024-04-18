# seL4 Nix utils readme

[![Nix](https://github.com/DLR-FT/seL4-nix-utils/actions/workflows/nix.yaml/badge.svg)](https://github.com/DLR-FT/seL4-nix-utils/actions/workflows/nix.yaml)

This repo contains a number of Nix expressions for the seL4 ecosystem.
Among other things this includes:

- derivations to build the seL4 kernel
- derivations to build our ongoing seL4-rs project, a Rust based wrapper arround seL4
- derivations to build the seL4-test suite for various (simulated and phyiscal) targets
- a generic [FOD](https://nixos.org/manual/nixpkgs/stable/#fixed-output-derivation) fetcher for [Google's repo tool](https://android.googlesource.com/tools/repo)

# About code style and DRY

The code especially in the `flake.nix` is very repetetive.
This is fully intentional, we want the code to be easily copy-pasteable.
Nix' expressive syntax would allow for the various things to be condensed into a much shorter generator expression, however, that is detrimental to the goal of this repo:
providing accessible information on how to compile seL4 related projects in Nix.

# Useful Links

- [seL4 Reference Manual](https://sel4.systems/Info/Docs/seL4-manual-latest.pdf)
- [seL4 Hardware Support](https://docs.sel4.systems/Hardware/)
- [nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)
