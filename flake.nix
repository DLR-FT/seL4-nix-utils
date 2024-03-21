{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... } @ inputs: flake-utils.lib.eachSystem [ "x86_64-linux" ]
    (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
      in
      {
        packages = {
          # python dependencies for seL4
          # these are not actually part of the nixpkgs, but provided over the default overlay of
          # this flake
          guardonce = pkgs.python3Packages.guardonce;
          pyfdt = pkgs.python3Packages.pyfdt;
          concurrencytest = pkgs.python3Packages.concurrencytest;
          seL4-deps = pkgs.python3Packages.seL4-deps;
          camkes-deps = pkgs.python3Packages.camkes-deps;

          #
          ### seL4 Kernel Flavours
          #
          seL4-kernel-arm-hyp = pkgs.callPackage pkgs/seL4-kernel.nix {
            config = "ARM_HYP_verified";
          };

          seL4-kernel-arm-mcs = pkgs.callPackage pkgs/seL4-kernel.nix {
            config = "ARM_MCS_verified";
          };

          seL4-kernel-arm = pkgs.callPackage pkgs/seL4-kernel.nix {
            config = "ARM_verified";
          };

          seL4-kernel-riscv64-mcs = pkgs.callPackage pkgs/seL4-kernel.nix {
            config = "RISCV64_MCS_verified";
          };

          seL4-kernel-riscv64 = pkgs.callPackage pkgs/seL4-kernel.nix {
            config = "RISCV64_verified";
          };

          seL4-kernel-x64 = pkgs.callPackage pkgs/seL4-kernel.nix {
            config = "X64_verified";
          };

          #
          ### seL4 kernel + userspace flavours
          #
          seL4-moritz-fork-arm-hyp = pkgs.callPackage pkgs/seL4-moritz-fork.nix {
            config = "ARM_HYP_verified";
            extraCmakeFlags = [
              "-DPLATFORM=zynq7000"
              "-DRELEASE=FALSE"
              "-DVERIFICATION=FALSE"
            ];
          };

          seL4-moritz-fork-arm-mcs = pkgs.callPackage pkgs/seL4-moritz-fork.nix {
            config = "ARM_MCS_verified";
            extraCmakeFlags = [
              "-DPLATFORM=zynq7000"
              "-DRELEASE=FALSE"
              "-DVERIFICATION=FALSE"
              "-DKernelIsMCS=ON"
            ];
          };

          seL4-moritz-fork-arm = pkgs.callPackage pkgs/seL4-moritz-fork.nix {
            config = "ARM_verified";
            extraCmakeFlags = [
              "-DPLATFORM=zynq7000"
              "-DRELEASE=FALSE"
              "-DVERIFICATION=FALSE"
            ];
          };

          seL4-moritz-fork-riscv64-mcs = pkgs.callPackage pkgs/seL4-moritz-fork.nix {
            config = "RISCV64_MCS_verified";
            extraCmakeFlags = [
              "-DPLATFORM=hifive"
              "-DRELEASE=FALSE"
              "-DVERIFICATION=FALSE"
              "-DKernelIsMCS=ON"
            ];
          };

          seL4-moritz-fork-riscv64 = pkgs.callPackage pkgs/seL4-moritz-fork.nix {
            config = "RISCV64_verified";
            extraCmakeFlags = [
              "-DPLATFORM=hifive"
              "-DRELEASE=FALSE"
              "-DVERIFICATION=FALSE"
            ];
          };

          seL4-moritz-fork-x64 = pkgs.callPackage pkgs/seL4-moritz-fork.nix {
            config = "X64_verified";
            extraCmakeFlags = [
              "-DPLATFORM=pc99"
              "-DRELEASE=FALSE"
              "-DVERIFICATION=FALSE"
            ];
          };


          #
          ### seL4 test suite for various platforms
          #
          seL4-test-aarch64-imx8mq-evk = (import nixpkgs {
            inherit system;
            crossSystem.config = "aarch64-unknown-linux-musl";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=imx8mq-evk" ]; };


          seL4-test-aarch64-rpi4 = (import nixpkgs {
            inherit system;
            crossSystem.config = "aarch64-unknown-linux-musl";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=rpi4"
                "-DRPI4_MEMORY=1024" # alternative one of 2048 4096 8192
              ];
            };


          seL4-test-aarch64-zcu102 = (import nixpkgs {
            inherit system;
            crossSystem.config = "aarch64-unknown-linux-musl";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=zcu102" ]; };


          seL4-test-armv7a-rpi3 = (import nixpkgs {
            inherit system;
            crossSystem.config = "armv7a-unknown-linux-musleabihf";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=rpi3" ]; };


          seL4-test-armv7a-zynq7000 = (import nixpkgs {
            inherit system;
            crossSystem.config = "armv7a-unknown-linux-musleabihf";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=zynq7000" ]; };


          seL4-test-armv7a-zynq7000-simulate = (import nixpkgs {
            inherit system;
            crossSystem.config = "armv7a-unknown-linux-musleabihf";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=zynq7000"
                "-DSIMULATION=1"
              ];
            };


          seL4-test-riscv32-spike = (import nixpkgs {
            inherit system;
            crossSystem.config = "riscv32-unknown-linux-gnu";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=spike" ]; };


          seL4-test-riscv32-spike-simulate = (import nixpkgs {
            inherit system;
            crossSystem.config = "riscv32-unknown-linux-gnu";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=spike"
                "-DSIMULATION=1"
              ];
            };


          seL4-test-riscv64-spike = (import nixpkgs {
            inherit system;
            crossSystem.config = "riscv64-unknown-linux-musl";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=spike" ]; };


          seL4-test-riscv64-spike-simulate = (import nixpkgs {
            inherit system;
            crossSystem.config = "riscv64-unknown-linux-musl";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=spike"
                "-DSIMULATION=1"
              ];
            };


          seL4-test-i686-ia32 = (import nixpkgs {
            inherit system;
            crossSystem.config = "i686-unknown-linux-musl";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=ia32" ]; };


          seL4-test-i686-ia32-simulate = (import nixpkgs {
            inherit system;
            crossSystem.config = "i686-unknown-linux-musl";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=ia32"
                "-DSIMULATION=TRUE"
              ];
            };


          seL4-test-x86_64-x86_64 = (import nixpkgs {
            inherit system;
            crossSystem.config = "x86_64-unknown-linux-musl";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=x86_64" ]; };


          seL4-test-x86_64-x86_64-simulate = (import nixpkgs {
            inherit system;
            crossSystem.config = "x86_64-unknown-linux-musl";
            overlays = [ self.overlays.default ];
          }).callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=x86_64"
                "-DSIMULATION=TRUE"
              ];
            };
        };

        #
        ### DevShell
        #

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
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
            gcc-arm-embedded-8

            # CAmkES
            stack
            haskell.compiler.ghc902

            # both
            python3Packages.camkes-deps # includes seL4-deps
          ];
          shellHook = ''
            export NIX_PATH=nixpkgs=${inputs.nixpkgs}:$NIX_PATH
            cat << EOF
            repo init -u https://github.com/seL4/sel4-tutorials-manifest
            repo sync
            rm -rf tutorial*
            mkdir tutorial
            cd tutorial
            ../init --tut hello-world
            cd ../tutorial_build
            ninja
            ./check
            EOF
          '';
        };

        # always check these
        checks = {
          nixpkgs-fmt = pkgs.runCommand "nixpkgs-fmt"
            {
              nativeBuildInputs = [ pkgs.nixpkgs-fmt ];
            } "nixpkgs-fmt --check ${./.}; touch $out";
        };

        # instructions for the CI server
        hydraJobs =
          let
            inherit (nixpkgs.lib.attrsets) filterAttrs;
            checks = self.checks.${system};
            packages = self.packages.${system};
          in
          (filterAttrs (n: v: n != "default") packages) // checks;
      }) // {
    # declare overlay with added deps, i. e. the python packages not available in official nixpkgs
    overlays.default = import ./overlay.nix;
  };
}
