{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, treefmt-nix, ... } @ inputs: flake-utils.lib.eachSystem [ "x86_64-linux" ]
    (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

        #
        ### Custom cross-compilation Environments
        #
        pkgsCrossArmv7l = (import nixpkgs {
          inherit system;
          crossSystem.config = "armv7l-unknown-linux-gnueabihf";
          overlays = [ self.overlays.default ];
        });

        pkgsCrossAarch64 = (import nixpkgs {
          inherit system;
          crossSystem.config = "aarch64-unknown-linux-gnu";
          overlays = [ self.overlays.default ];
        });

        pkgsCrossArmv7lOldBintools = (import nixpkgs {
          inherit system;
          crossSystem.config = "armv7l-unknown-linux-gnueabihf";
          overlays = [ self.overlays.default self.overlays.oldBintools ];
        });

        pkgsCrossAarch64OldBintools = (import nixpkgs {
          inherit system;
          crossSystem.config = "aarch64-unknown-linux-gnu";
          overlays = [ self.overlays.default self.overlays.oldBintools ];
        });

        pkgsCrossi686 = (import nixpkgs {
          inherit system;
          crossSystem.config = "i686-unknown-linux-gnu";
          overlays = [ self.overlays.default ];
        });

        pkgsCrossx86_64 = (import nixpkgs {
          inherit system;
          crossSystem.config = "x86_64-unknown-linux-musl";
          overlays = [ self.overlays.default ];
        });
      in
      {
        packages = {
          #
          ### Re-export toolchains to cause proper cashing
          #
          crossStdenvAarch64 = pkgsCrossAarch64.stdenvNoLibs;
          crossStdenvArmv7l = pkgsCrossArmv7l.stdenvNoLibs;
          crossStdenvAarch64OldBintools = pkgsCrossAarch64OldBintools.stdenvNoLibs;
          crossStdenvArmv7lOldBintools = pkgsCrossArmv7lOldBintools.stdenvNoLibs;
          crossStdenvi686 = pkgsCrossi686.stdenvNoLibs;
          crossStdenvx86_64 = pkgsCrossx86_64.stdenvNoLibs;


          #
          ### seL4 related tools and dependencies
          #
          capDL-tool = pkgs.capDL-tool;

          # python dependencies for seL4
          # these are not actually part of the nixpkgs, but provided over the default overlay of
          # this flake
          guardonce = pkgs.python3Packages.guardonce;
          pyfdt = pkgs.python3Packages.pyfdt;
          concurrencytest = pkgs.python3Packages.concurrencytest;
          seL4-deps = pkgs.python3Packages.seL4-deps;
          camkes-deps = pkgs.python3Packages.camkes-deps;


          #
          ### microkit(-sdk)
          #
          microkit-sdk = pkgs.microkit-sdk;

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

          # seL4-moritz-fork-riscv64-mcs = pkgs.callPackage pkgs/seL4-moritz-fork.nix {
          #   config = "RISCV64_MCS_verified";
          #   extraCmakeFlags = [
          #     "-DPLATFORM=hifive"
          #     "-DRELEASE=FALSE"
          #     "-DVERIFICATION=FALSE"
          #     "-DKernelIsMCS=ON"
          #   ];
          # };

          # seL4-moritz-fork-riscv64 = pkgs.callPackage pkgs/seL4-moritz-fork.nix {
          #   config = "RISCV64_verified";
          #   extraCmakeFlags = [
          #     "-DPLATFORM=hifive"
          #     "-DRELEASE=FALSE"
          #     "-DVERIFICATION=FALSE"
          #   ];
          # };

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
          seL4-test-aarch64-imx8mq-evk = pkgsCrossAarch64.callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=imx8mq-evk" ]; };


          seL4-test-aarch64-rpi4-1GB = pkgsCrossAarch64.callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=rpi4"
                "-DRPI4_MEMORY=1024" # one of 1024 2048 4096 8192
              ];
            };

          seL4-test-aarch64-rpi4-2GB = pkgsCrossAarch64.callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=rpi4"
                "-DRPI4_MEMORY=2048" # one of 1024 2048 4096 8192
              ];
            };

          seL4-test-aarch64-rpi4-4GB = pkgsCrossAarch64.callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=rpi4"
                "-DRPI4_MEMORY=4096" # one of 1024 2048 4096 8192
              ];
            };

          seL4-test-aarch64-rpi4-8GB = pkgsCrossAarch64.callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=rpi4"
                "-DRPI4_MEMORY=8192" # one of 1024 2048 4096 8192
              ];
            };

          seL4-test-aarch64-zcu102 = pkgsCrossAarch64.callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=zcu102" ]; };


          seL4-test-armv7l-rpi3 = pkgsCrossArmv7l.callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=rpi3" ]; };


          seL4-test-armv7l-zynq7000 = pkgsCrossArmv7l.callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=zynq7000" ]; };


          seL4-test-armv7l-zynq7000-simulate = pkgsCrossArmv7l.callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=zynq7000"
                "-DSIMULATION=1"
              ];
            };


          # seL4-test-riscv32-spike = (import nixpkgs {
          #   inherit system;
          #   crossSystem.config = "riscv32-unknown-linux-gnu";
          #   overlays = [ self.overlays.default ];
          # }).callPackage pkgs/seL4-test.nix
          #   { extraCmakeFlags = [ "-DPLATFORM=spike" ]; };


          # seL4-test-riscv32-spike-simulate = (import nixpkgs {
          #   inherit system;
          #   crossSystem.config = "riscv32-unknown-linux-gnu";
          #   overlays = [ self.overlays.default ];
          # }).callPackage pkgs/seL4-test.nix
          #   {
          #     extraCmakeFlags = [
          #       "-DPLATFORM=spike"
          #       "-DSIMULATION=1"
          #     ];
          #   };


          # seL4-test-riscv64-spike = (import nixpkgs {
          #   inherit system;
          #   crossSystem.config = "riscv64-unknown-linux-musl";
          #   overlays = [ self.overlays.default ];
          # }).callPackage pkgs/seL4-test.nix
          #   { extraCmakeFlags = [ "-DPLATFORM=spike" ]; };


          # seL4-test-riscv64-spike-simulate = (import nixpkgs {
          #   inherit system;
          #   crossSystem.config = "riscv64-unknown-linux-musl";
          #   overlays = [ self.overlays.default ];
          # }).callPackage pkgs/seL4-test.nix
          #   {
          #     extraCmakeFlags = [
          #       "-DPLATFORM=spike"
          #       "-DSIMULATION=1"
          #     ];
          #   };


          seL4-test-i686-ia32 = pkgsCrossi686.callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=ia32" ]; };


          seL4-test-i686-ia32-simulate = pkgsCrossi686.callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=ia32"
                "-DSIMULATION=TRUE"
              ];
            };


          seL4-test-x86_64-x86_64 = pkgsCrossx86_64.callPackage pkgs/seL4-test.nix
            { extraCmakeFlags = [ "-DPLATFORM=x86_64" ]; };


          seL4-test-x86_64-x86_64-simulate = pkgsCrossx86_64.callPackage pkgs/seL4-test.nix
            {
              extraCmakeFlags = [
                "-DPLATFORM=x86_64"
                "-DSIMULATION=TRUE"
              ];
            };


          #
          ### seL4 CAmkES VM Examples
          #
          seL4-camkes-vm-examples-aarch64-tx1 = pkgs.callPackage pkgs/seL4-camkes-vm-examples.nix {
            stdenvNoLibs = pkgsCrossAarch64OldBintools.overrideCC pkgsCrossAarch64OldBintools.stdenvNoLibs pkgsCrossAarch64OldBintools.stdenvNoLibs.cc;
            extraCmakeFlags = [
              "-DPLATFORM=tx1"
              "-DCAMKES_VM_APP=vm_minimal"
            ];
          };


          seL4-camkes-vm-examples-aarch64-tx2 = pkgs.callPackage pkgs/seL4-camkes-vm-examples.nix {
            stdenvNoLibs = pkgsCrossAarch64OldBintools.overrideCC pkgsCrossAarch64OldBintools.stdenvNoLibs pkgsCrossAarch64OldBintools.stdenvNoLibs.cc;
            extraCmakeFlags = [
              "-DPLATFORM=tx2"
              "-DCAMKES_VM_APP=vm_minimal"
            ];
          };


          seL4-camkes-vm-examples-aarch64-qemu-arm-virt = pkgs.callPackage pkgs/seL4-camkes-vm-examples.nix {
            stdenvNoLibs = pkgsCrossAarch64OldBintools.overrideCC pkgsCrossAarch64OldBintools.stdenvNoLibs pkgsCrossAarch64OldBintools.stdenvNoLibs.cc;
            extraCmakeFlags = [
              "-DPLATFORM=qemu-arm-virt"
              "-DCAMKES_VM_APP=vm_minimal"
            ];
          };


          seL4-camkes-vm-examples-aarch64-zcu102 = pkgs.callPackage pkgs/seL4-camkes-vm-examples.nix {
            stdenvNoLibs = pkgsCrossAarch64OldBintools.overrideCC pkgsCrossAarch64OldBintools.stdenvNoLibs pkgsCrossAarch64OldBintools.stdenvNoLibs.cc;
            extraCmakeFlags = [
              "-DPLATFORM=zcu102"
              "-DCAMKES_VM_APP=vm_minimal"
            ];
          };


          seL4-camkes-vm-examples-armv7l-exynos5422 = pkgs.callPackage pkgs/seL4-camkes-vm-examples.nix {
            stdenvNoLibs = pkgsCrossArmv7lOldBintools.overrideCC pkgsCrossArmv7lOldBintools.stdenvNoLibs pkgsCrossArmv7lOldBintools.stdenvNoLibs.cc;
            extraCmakeFlags = [
              "-DPLATFORM=exynos5422"
              "-DCAMKES_VM_APP=vm_minimal"
            ];
          };


          #
          ### Arm Trusted Firmware
          #
          atf-aarch64-zcu102 = pkgsCrossAarch64.buildArmTrustedFirmware rec {
            platform = "zynqmp";
            extraMeta.platforms = [ "aarch64-linux" ];
            extraMakeFlags = [ "RESET_TO_BL31=1" ];
            filesToInstall = [ "build/${platform}/release/bl31.bin" ];
            version = "xilinx-v2023.2";
            src = pkgs.fetchFromGitHub {
              owner = "Xilinx";
              repo = "arm-trusted-firmware";
              rev = version;
              hash = "sha256-RvdBsskiSgquwnDf0g0dU8P6v4QxK4OqhtkF5K7lfyI=";
            };
          };


          #
          ### Firmware
          #
          pmufw-mblaze-zcu102 = (import nixpkgs {
            inherit system;
            crossSystem.config = "microblazeel-none-elf";
            overlays = [ self.overlays.default ];
          }).callPackage ./pkgs/xilinx-pmufw.nix
            { };


          #
          ### UBoot with specific patches
          #
          uboot-aarch64-rpi4 = pkgsCrossAarch64.ubootRaspberryPi4_64bit;


          # For more information on compiling the Xilinx U-Boot fork see
          # https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18841973/Build+U-Boot
          uboot-aarch64-zcu102 = pkgsCrossAarch64.buildUBoot rec {
            extraMeta.platforms = [ "aarch64-linux" ];
            defconfig = "xilinx_zynqmp_virt_defconfig";
            # The `DEVICE_TREE` environment variable must only be propagated __after__ the initial
            # `make xilinx_zynqmp_virt_defconfig` call.
            preInstall = ''
              export DEVICE_TREE="zynqmp-zcu102-rev1.0"
            '';
            filesToInstall = [ "spl/boot.bin" "u-boot.elf" "u-boot.img" ];
            version = "xilinx-v2023.2";
            dontPatch = true; # avoid unapplicable raspberrypi patches

            # u-boot-xlnx ignores the CONFIG_ARMV8_SWITCH_TO_EL1 macro, and always unconditionally
            # boots into EL1 when doing `go`. This little patch changes that behavior to stay in
            # EL2, so that seL4 can happily boot even in hypervisor mode.
            prePatch = ''
              substituteInPlace board/xilinx/zynqmp/zynqmp.c \
                --replace armv8_switch_to_el1 armv8_switch_to_el2
            '';

            src = pkgs.fetchFromGitHub {
              owner = "Xilinx";
              repo = "u-boot-xlnx";
              rev = version;
              hash = "sha256-tSOw7+Pe3/JYIgrPYB6exPzfGrRTuolxXXTux80w/X8=";
            };
          };


          # based of https://github.com/Xilinx/u-boot-xlnx/blob/master/doc/board/xilinx/zynq.rst
          uboot-armv7l-zynq-zc702 = pkgsCrossArmv7l.buildUBoot rec {
            extraMeta.platforms = [ "armv7l-linux" ];
            defconfig = "xilinx_zynq_virt_defconfig";
            env.DEVICE_TREE = "zynq-zc702";
            filesToInstall = [ "spl/boot.bin" "u-boot.elf" "u-boot.img" ];
            version = "xilinx-v2023.2";
            dontPatch = true; # avoid unapplicable raspberrypi patches
            src = pkgs.fetchFromGitHub {
              owner = "Xilinx";
              repo = "u-boot-xlnx";
              rev = version;
              hash = "sha256-tSOw7+Pe3/JYIgrPYB6exPzfGrRTuolxXXTux80w/X8=";
            };
          };


          #
          ### SD Card
          #
          sd-aarch64-rpi4 =
            let
              inherit (pkgs) lib;
              # Reference: https://www.raspberrypi.com/documentation/computers/config_txt.html
              # Default: https://github.com/RPi-Distro/pi-gen/blob/master/stage1/00-boot-files/files/config.txt
              config = {
                arm_boost = 1;
                arm_64bit = 1;
                kernel = "u-boot.bin";
                dtoverlay = "disable-bt";
                enable_uart = 1;
                uart_2ndstage = 1;
              };
              config_txt = pkgs.writeText "config.txt" (lib.generators.toKeyValue { } config);
            in
            pkgs.runCommand "assemble-sd" { } ''
              mkdir -- $out

              # copy firmware stuff
              pushd ${pkgs.raspberrypifw}/share/raspberrypi/boot
              cp --recursive -- bootcode.bin start4.elf bcm2711-rpi-4-b.dtb overlays $out/
              popd

              # copy u-boot
              cp ${self.packages.${system}.uboot-aarch64-rpi4}/u-boot.bin $out/

              # config.txt
              cp ${config_txt} $out/config.txt
            '';
        };


        #
        ### DevShells
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
        };

        devShells.microkit = pkgs.mkShell.override { stdenv = pkgs.stdenvNoCC; } {
          nativeBuildInputs = with pkgs; [
            pkgsCross.aarch64-multiplatform.stdenv.cc
            pkgsCross.aarch64-multiplatform.stdenv.cc.bintools
            bear
            gnumake
            qemu
            microkit-sdk
          ];

          # mitigates the following errors:
          # undefined reference to `__stack_chk_guard'
          # undefined reference to `__stack_chk_fail'
          hardeningDisable = [ "all" ];
          env.MICROKIT_SDK = pkgs.microkit-sdk;
        };


        #
        ### Checks & CI
        #

        # for `nix fmt`
        formatter = treefmtEval.config.build.wrapper;

        # for `nix flake check`
        checks.formatting = treefmtEval.config.build.check self;

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

    # seL4's musllibc fork can't stand modern bintools because its too old.
    overlays.oldBintools = final: prev: {
      bintools = prev.wrapBintoolsWith {
        bintools = prev.binutils-unwrapped_2_38;
        libc = prev.stdenv.cc.libc;
      };
    };
  };
}
