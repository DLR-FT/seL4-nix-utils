{
  self,
  system,
  pkgs,
  pkgsCross,
  inputs,
  versions,
}:

{
  #
  ### Re-export toolchains to cause proper caching
  #
  toolchain-aarch64-elf = pkgsCross.aarch64-unknown-none-elf.stdenvNoLibs;
  toolchain-aarch64-linux = pkgsCross.aarch64-unknown-linux-gnu.stdenvNoLibs;
  toolchain-armv7l-eabihf = pkgsCross.armv7l-unknown-none-eabihf.stdenvNoLibs;
  toolchain-armv7l-linux = pkgsCross.armv7l-unknown-linux-gnueabihf.stdenvNoLibs;
  toolchain-i686-elf = pkgsCross.i686-unknown-none-elf.stdenvNoLibs;
  toolchain-riscv32-elf = pkgsCross.riscv32-unknown-none-elf.stdenvNoLibs;
  toolchain-riscv64-elf = pkgsCross.riscv64-unknown-none-elf.stdenvNoLibs;
  toolchain-riscv64-linux = pkgsCross.riscv64-unknown-linux-gnu.stdenvNoLibs;
  toolchain-x86_64-elf = pkgsCross.x86_64-unknown-none-elf.stdenvNoLibs;

  #
  ### seL4 related tools and dependencies
  #
  capDL-tool = pkgs.capDL-tool;

  # python dependencies for seL4
  # these are not actually part of the nixpkgs, but provided over the default overlay of
  # this flake (except pyfdt, which is now in nixpkgs)
  guardonce = pkgs.python3Packages.guardonce;
  pyfdt = pkgs.python3Packages.pyfdt;
  concurrencytest = pkgs.python3Packages.concurrencytest;

  #
  ### microkit(-sdk)
  #
  microkit-sdk = pkgs.microkit-sdk;

  #
  ### Linux
  #

  /*
    Note: there used to be some stuff around Linux kernel hacking and tinkering. This
    investigation got widened and deepend, living along in it's own repo now:
    https://github.com/wucke13/minimal-nixos/
  */

  #
  ### seL4 verified kernel flavours
  #
  seL4-kernel-aarch64 = pkgsCross.aarch64-unknown-none-elf.seL4-kernel.override {
    verifiedConfig = "AARCH64_verified";
  };

  seL4-kernel-arm-hyp-exynos5 = pkgsCross.armv7l-unknown-none-eabihf.seL4-kernel.override {
    verifiedConfig = "ARM_HYP_exynos5_verified";
  };

  seL4-kernel-arm-hyp = pkgsCross.armv7l-unknown-none-eabihf.seL4-kernel.override {
    verifiedConfig = "ARM_HYP_verified";
  };

  seL4-kernel-arm-mcs = pkgsCross.armv7l-unknown-none-eabihf.seL4-kernel.override {
    verifiedConfig = "ARM_MCS_verified";
  };

  seL4-kernel-arm-imx8mm = pkgsCross.armv7l-unknown-none-eabihf.seL4-kernel.override {
    verifiedConfig = "ARM_imx8mm_verified";
  };

  seL4-kernel-arm = pkgsCross.armv7l-unknown-none-eabihf.seL4-kernel.override {
    verifiedConfig = "ARM_verified";
  };

  seL4-kernel-riscv64-mcs = pkgsCross.riscv64-unknown-none-elf.seL4-kernel.override {
    verifiedConfig = "RISCV64_MCS_verified";
  };

  seL4-kernel-riscv64-elf = pkgsCross.riscv64-unknown-none-elf.seL4-kernel.override {
    verifiedConfig = "RISCV64_verified";
  };

  seL4-kernel-x64 = pkgsCross.x86_64-unknown-none-elf.seL4-kernel.override {
    verifiedConfig = "X64_verified";
  };

  #
  ### seL4 test suite for various platforms
  #
  seL4-test-aarch64-imx8mq-evk = pkgsCross.aarch64-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [ "-DPLATFORM=imx8mq-evk" ];
  };

  seL4-test-aarch64-rpi4-1GB = pkgsCross.aarch64-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [
      "-DPLATFORM=rpi4"
      "-DRPI4_MEMORY=1024" # one of 1024 2048 4096 8192
    ];
  };

  seL4-test-aarch64-rpi4-2GB = pkgsCross.aarch64-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [
      "-DPLATFORM=rpi4"
      "-DRPI4_MEMORY=2048" # one of 1024 2048 4096 8192
    ];
  };

  seL4-test-aarch64-rpi4-4GB = pkgsCross.aarch64-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [
      "-DPLATFORM=rpi4"
      "-DRPI4_MEMORY=4096" # one of 1024 2048 4096 8192
    ];
  };

  seL4-test-aarch64-rpi4-8GB = pkgsCross.aarch64-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [
      "-DPLATFORM=rpi4"
      "-DRPI4_MEMORY=8192" # one of 1024 2048 4096 8192
    ];
  };

  seL4-test-aarch64-zcu102 = pkgsCross.aarch64-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [ "-DPLATFORM=zcu102" ];
  };

  seL4-test-armv7l-rpi3 = pkgsCross.armv7l-unknown-none-eabihf.seL4-test.override {
    extraCmakeFlags = [ "-DPLATFORM=rpi3" ];
  };

  seL4-test-armv7l-zynq7000 = pkgsCross.armv7l-unknown-none-eabihf.seL4-test.override {
    extraCmakeFlags = [ "-DPLATFORM=zynq7000" ];
  };

  seL4-test-armv7l-zynq7000-simulate = pkgsCross.armv7l-unknown-none-eabihf.seL4-test.override {
    extraCmakeFlags = [
      "-DPLATFORM=zynq7000"
      "-DSIMULATION=1"
    ];
  };

  seL4-test-riscv32-spike = pkgsCross.riscv32-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [ "-DPLATFORM=spike" ];
  };

  seL4-test-riscv32-spike-simulate = pkgsCross.riscv32-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [
      "-DPLATFORM=spike"
      "-DSIMULATION=1"
    ];
  };

  seL4-test-riscv64-spike = pkgsCross.riscv64-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [ "-DPLATFORM=spike" ];
  };

  seL4-test-riscv64-spike-simulate = pkgsCross.riscv64-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [
      "-DPLATFORM=spike"
      "-DSIMULATION=1"
    ];
  };

  seL4-test-i686-ia32 = pkgsCross.i686-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [ "-DPLATFORM=ia32" ];
  };

  seL4-test-i686-ia32-simulate = pkgsCross.i686-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [
      "-DPLATFORM=ia32"
      "-DSIMULATION=TRUE"
    ];
  };

  seL4-test-x86_64-x86_64 = pkgsCross.x86_64-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [ "-DPLATFORM=x86_64" ];
  };

  seL4-test-x86_64-x86_64-simulate = pkgsCross.x86_64-unknown-none-elf.seL4-test.override {
    extraCmakeFlags = [
      "-DPLATFORM=x86_64"
      "-DSIMULATION=TRUE"
    ];
  };

  #
  ### seL4 CAmkES VM Examples
  #
  seL4-camkes-vm-examples-aarch64-tx1 =
    pkgsCross.aarch64-unknown-none-elf.seL4-camkes-vm-examples.override
      {
        extraCmakeFlags = [
          "-DPLATFORM=tx1"
          "-DCAMKES_VM_APP=vm_minimal"
        ];
      };

  seL4-camkes-vm-examples-aarch64-tx2 =
    pkgsCross.aarch64-unknown-none-elf.seL4-camkes-vm-examples.override
      {
        extraCmakeFlags = [
          "-DPLATFORM=tx2"
          "-DCAMKES_VM_APP=vm_minimal"
        ];
      };

  seL4-camkes-vm-examples-aarch64-qemu-arm-virt =
    pkgsCross.aarch64-unknown-none-elf.seL4-camkes-vm-examples.override
      {
        extraCmakeFlags = [
          "-DPLATFORM=qemu-arm-virt"
          "-DCAMKES_VM_APP=vm_minimal"
        ];
      };

  seL4-camkes-vm-examples-aarch64-zcu102 =
    pkgsCross.aarch64-unknown-none-elf.seL4-camkes-vm-examples.override
      {
        extraCmakeFlags = [
          "-DPLATFORM=zcu102"
          "-DCAMKES_VM_APP=vm_minimal"
        ];
      };

  seL4-camkes-vm-examples-armv7l-exynos5422 =
    pkgsCross.armv7l-unknown-none-eabihf.seL4-camkes-vm-examples.override
      {
        extraCmakeFlags = [
          "-DPLATFORM=exynos5422"
          "-DCAMKES_VM_APP=vm_minimal"
        ];
      };

  #
  ### Arm Trusted Firmware
  #
  atf-aarch64-zcu102 = pkgsCross.aarch64-unknown-linux-gnu.buildArmTrustedFirmware {
    platform = "zynqmp";
    extraMeta.platforms = [ "aarch64-linux" ];
    extraMakeFlags = [ "RESET_TO_BL31=1" ];
    filesToInstall = [ "build/zynqmp/release/bl31.bin" ];
    version = versions.xilinx-atf;
    src = inputs.xilinx-atf-src;
  };

  #
  ### Firmware
  #
  opensbi-riscv64-cva6 = (
    pkgsCross.riscv64-unknown-linux-gnu.opensbi.overrideAttrs (_: {
      version = versions.opensbi;
      src = inputs.opensbi-src;
      env.NIX_CFLAGS_COMPILE = "-march=rv64imafdc_zicsr_zifencei";
    })
  );

  pmufw-mblaze-zcu102 = pkgsCross.microblazeel-none-elf.callPackage ../pkgs/xilinx-pmufw.nix {
    src = inputs.xilinx-embeddedsw-src;
    version = versions.xilinx-embeddedsw;
  };

  #
  ### UBoot with specific patches
  #
  uboot-aarch64-rpi4 = pkgsCross.aarch64-unknown-linux-gnu.ubootRaspberryPi4_64bit;

  # For more information on compiling the Xilinx U-Boot fork see
  # https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18841973/Build+U-Boot
  uboot-aarch64-zcu102 = pkgsCross.aarch64-unknown-linux-gnu.buildUBoot {
    extraMeta.platforms = [ "aarch64-linux" ];
    defconfig = "xilinx_zynqmp_virt_defconfig";
    # The `DEVICE_TREE` environment variable must only be propagated __after__ the initial
    # `make xilinx_zynqmp_virt_defconfig` call.
    preInstall = ''
      export DEVICE_TREE="zynqmp-zcu102-rev1.0"
    '';
    filesToInstall = [
      "spl/boot.bin"
      "u-boot.elf"
      "u-boot.img"
    ];
    version = versions.xilinx-uboot;
    src = inputs.xilinx-uboot-src;

    # u-boot-xlnx ignores the CONFIG_ARMV8_SWITCH_TO_EL1 macro, and always unconditionally
    # boots into EL1 when doing `go`. This little patch changes that behavior to stay in
    # EL2, so that seL4 can happily boot even in hypervisor mode.
    prePatch = ''
      substituteInPlace board/xilinx/zynqmp/zynqmp.c \
        --replace armv8_switch_to_el1 armv8_switch_to_el2
    '';
  };

  # based of https://github.com/Xilinx/u-boot-xlnx/blob/master/doc/board/xilinx/zynq.rst
  uboot-armv7l-zynq-zc702 = pkgsCross.armv7l-unknown-linux-gnueabihf.buildUBoot {
    extraMeta.platforms = [ "armv7l-linux" ];
    defconfig = "xilinx_zynq_virt_defconfig";
    env.DEVICE_TREE = "zynq-zc702";
    filesToInstall = [
      "spl/boot.bin"
      "u-boot.elf"
      "u-boot.img"
    ];
    version = versions.xilinx-uboot;
    src = inputs.xilinx-uboot-src;
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
}
