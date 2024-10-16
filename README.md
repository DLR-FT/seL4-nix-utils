# seL4 Nix utils readme

[![Nix](https://github.com/DLR-FT/seL4-nix-utils/actions/workflows/nix.yaml/badge.svg)](https://github.com/DLR-FT/seL4-nix-utils/actions/workflows/nix.yaml)

This repo contains a number of Nix expressions for the seL4 ecosystem.
Among other things this includes:

- derivations to build the seL4 kernel
- derivations to build our ongoing seL4-rs project, a Rust based wrapper arround seL4
- derivations to build the seL4-test suite for various (simulated and phyiscal) targets
- a generic [FOD](https://nixos.org/manual/nixpkgs/stable/#fixed-output-derivation) fetcher for
  [Google's repo tool](https://android.googlesource.com/tools/repo)

# Caching

Many of the derivations in this repository depend on huge builds, which are not cached by
<https://cache.nixos.org/>. To spare you (and us) hours of compiling cross-compilers, the
CI-pipeline configured for this repository pushes its binary artifacts to the
[DLR-FT Cachix](https://app.cachix.org/cache/dlr-ft). Hence, you may use the following binary cache
with [Cachix](https://app.cachix.org):
`dlr-ft.cachix.org-1:QalYjdLh69S57wX6br7xTVEtOWDoPLXTMTUSurVKnVg=`

To do so, simply invoke the `cachix` executable as followed, before `nix build` or `nix develop`:

```console
cachix use dlr-ft
```

Please note: while we try to keep the relevant artifacts in the Cachix, there might be times
at which some of the artifacts have been evicted from the cache; this is a best-effort to make
everybody's life easier. There is no guarantee that all (or in fact any) of the dependencies to
build this repo's derivations is in the cache.

# About code style and DRY

The code especially in the `flake.nix` is very repetitive.
This is fully intentional, we want the code to be easily copy-pasteable.
Nix' expressive syntax would allow for the various things to be condensed into a much shorter generator expression, however, that is detrimental to the goal of this repo:
providing accessible information on how to compile seL4 related projects in Nix.

# Useful Links

- [seL4 Reference Manual](https://sel4.systems/Info/Docs/seL4-manual-latest.pdf)
- [seL4 Hardware Support](https://docs.sel4.systems/Hardware/)
- [nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)
