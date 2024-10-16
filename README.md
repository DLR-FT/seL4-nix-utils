# seL4 Nix utils readme

[![Nix](https://github.com/DLR-FT/seL4-nix-utils/actions/workflows/nix.yaml/badge.svg)](https://github.com/DLR-FT/seL4-nix-utils/actions/workflows/nix.yaml)

This repo contains a number of Nix expressions for the seL4 ecosystem.
Among other things this includes:

- derivations to build the seL4 kernel
- derivations to build our ongoing seL4-rs project, a Rust based wrapper arround seL4
- derivations to build the seL4-test suite for various (simulated and phyiscal) targets
- a generic [FOD](https://nixos.org/manual/nixpkgs/stable/#fixed-output-derivation) fetcher for
  [Google's repo tool](https://android.googlesource.com/tools/repo)

# Getting Started

Here you find a couple of examples to get started. Please note, that it is assumed you have Nix
already installed, with the experimental `flakes` and `nix-command` features enabled. If you have
these features not enabled, you can simply append the flag
`--extra-experimental-features 'flakes nix-command'` to the `nix {build,develop}` commands. For
convenience, we recommend you enable flakes permanently. Check out `man 5 nix.conf`, look for
`extra-experimental-features` (and on NixOS use
[`nix.settings`](https://search.nixos.org/options?query=nix.settings)).

If you do not have Nix installed, there are a couple of options, i.e.:

- Use the [official Nix installer](https://nixos.org/download/)
- Use the [Determinate Systems Nix Installer](https://github.com/DeterminateSystems/nix-installer),
  comes with the aforementioned experimental features pre-enabled
- Run the [`nixos/nix` Docker Container](https://hub.docker.com/r/nixos/nix)
- Run the [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) image, if you are on Windows

Once these preconditions are satisfied, here is an incomplete selection of what you could do:

```sh
# Play the Microkit tutorial
curl -L trustworthy.systems/Downloads/microkit_tutorial/tutorial.tar.gz -o tutorial.tar.gz
nix run nixpkgs#gnutar xf tutorial.tar.gz
nix develop github:DLR-FT/seL4-nix-utils#microkit


# Build & run seL4-test for x86_64-linux in QEMU
nix build github:DLR-FT/seL4-nix-utils#seL4-test-x86_64-x86_64-simulate
cd result && ./simulate


# Build U-Boot for the zcu102 platform, patched to enable EL2
# (Xilinx' U-Boot fork always switches to EL1, prohibiting seL4/Microkit in Hypervisor mode)
nix build github:DLR-FT/seL4-nix-utils#uboot-aarch64-zcu102


# Enter an interactive devshell for the seL4 test suite on the zynq7000, build it
nix develop github:DLR-FT/seL4-nix-utils#seL4-test-armv7l-zynq7000-simulate
unpackPhase && cd source # extract source code to new dir, cd there
configurePhase # configure the build dir, target etc.
ninja # compile


# Show all transitive build-time dependencies of Microkit
nix-store --query --tree $(nix eval --raw .\#microkit-sdk.drvPath)
```

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
