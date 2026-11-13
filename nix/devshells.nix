{ pkgs }:

{
  default = pkgs.mkShell {
    nativeBuildInputs =
      (with pkgs; [
        # seL4
        ccache
        cmake
        cmakeCurses
        curl
        doxygen
        dtc
        git
        gitRepo
        libxml2
        ncurses
        ninja
        protobuf
        qemu_full
        ubootTools

        # CAmkES
        stack
        haskell.compiler.ghc910
      ])
      ++ import ../pkgs/camkes-deps.nix {
        inherit (pkgs) cmake-format python3Packages;
      };
  };

  microkit = pkgs.mkShell.override { stdenv = pkgs.stdenvNoCC; } {
    nativeBuildInputs =
      (with pkgs; [
        bear
        gnumake
        qemu
        microkit-sdk
      ])
      ++ [
        pkgs.pkgsCross.aarch64-embedded.stdenv.cc.bintools.bintools
        pkgs.pkgsCross.aarch64-embedded.stdenv.cc.cc
        pkgs.pkgsCross.riscv64-embedded.stdenv.cc.bintools.bintools
        pkgs.pkgsCross.riscv64-embedded.stdenv.cc.cc
      ];

    # mitigates the following errors:
    # undefined reference to `__stack_chk_guard'
    # undefined reference to `__stack_chk_fail'
    hardeningDisable = [ "all" ];
    env.MICROKIT_SDK = pkgs.microkit-sdk;
  };
}
