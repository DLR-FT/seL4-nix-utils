{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Manifests (for auditing/syncing with scripts/sync_manifests.py)
    sel4test-manifest-src = {
      url = "github:seL4/sel4test-manifest/master";
      flake = false;
    };
    camkes-vm-examples-manifest-src = {
      url = "github:seL4/camkes-vm-examples-manifest/master";
      flake = false;
    };

    # Core & shared seL4 ecosystem sources (CI-passed master default.xml commits)
    seL4-src = {
      url = "github:seL4/seL4/c98d70adf15e8be7d3b99085c28d057069ba7155";
      flake = false;
    };
    capdl-src = {
      url = "github:seL4/capdl/55d2ef24aeb6de08f6bfc27ed1942eec54164a62";
      flake = false;
    };

    # BEGIN MANIFEST INPUTS
    camkes-tool-src = {
      url = "github:seL4/camkes-tool/23b7818c6c56a35fc6b5bafd642ff47d4226945f";
      flake = false;
    };
    camkes-vm-examples-src = {
      url = "github:seL4/camkes-vm-examples/75ad0399f9862e218170fa355ec84f1f910179a3";
      flake = false;
    };
    camkes-vm-images-src = {
      url = "github:seL4/camkes-vm-images/bafad64282c14d0bbf15468bfd6265e648d87d6c";
      flake = false;
    };
    camkes-vm-linux-src = {
      url = "github:seL4/camkes-vm-linux/f96dcc1bfc1677595767f4f478b554e344b842c7";
      flake = false;
    };
    camkes-vm-src = {
      url = "github:seL4/camkes-vm/9dff74fde712b412eeeccd5a53d6fff240a55b78";
      flake = false;
    };
    global-components-src = {
      url = "github:seL4/global-components/dd6a1ec846c422da85fdd6900df182095f9b7425";
      flake = false;
    };
    libzmq-src = {
      url = "github:zeromq/libzmq/d062edd8c142384792955796329baf1e5a3377cd";
      flake = false;
    };
    lwip-src = {
      url = "github:seL4/lwip/159e31b689577dbf69cf0683bbaffbd71fa5ee10";
      flake = false;
    };
    musllibc-src = {
      url = "github:seL4/musllibc/b0005f86fecbd6d0257b15363a5b013446914265";
      flake = false;
    };
    nanopb-src = {
      url = "github:nanopb/nanopb/cad3c18ef15a663e30e3e43e3a752b66378adec1";
      flake = false;
    };
    opensbi-sel4test-src = {
      url = "github:riscv-software-src/opensbi/234ed8e427f4d92903123199f6590d144e0d9351";
      flake = false;
    };
    picotcp-src = {
      url = "github:tass-belgium/picotcp/13c00a067190f5ec62340ed932a2bb833c366d63";
      flake = false;
    };
    polly-src = {
      url = "github:ruslo/polly/ef7e79c2c297d456f2742fd0b976f555d058d4e0";
      flake = false;
    };
    projects-libs-src = {
      url = "github:seL4/projects_libs/d2511a75ffadc5550c7f303a7641c0f731c30320";
      flake = false;
    };
    seL4-libs-src = {
      url = "github:seL4/seL4_libs/262a34dcb2f3285be01df9e5404d911132d567a6";
      flake = false;
    };
    seL4-projects-libs-src = {
      url = "github:seL4/seL4_projects_libs/b9137c0d905ce966a02b1c9a0c6c0e4beb48223b";
      flake = false;
    };
    seL4-tools-src = {
      url = "github:seL4/seL4_tools/6493e0c6fab360eb81a8115a49c9ca7bc280c48a";
      flake = false;
    };
    sel4runtime-src = {
      url = "github:seL4/sel4runtime/86489cf6efab9f314964e79468c036e9035394c7";
      flake = false;
    };
    sel4test-src = {
      url = "github:seL4/sel4test/f27e4f4cdd020ef9b37f15ded76a3b38477761f0";
      flake = false;
    };
    util-libs-src = {
      url = "github:seL4/util_libs/ef49a397b7044fc38b609a99a8c6265a97913b8e";
      flake = false;
    };
    # END MANIFEST INPUTS

    # Microkit sources
    microkit-src = {
      url = "github:seL4/microkit/2.4.0";
      flake = false;
    };
    microkit-seL4-src.follows = "seL4-src";
    # microkit-seL4-src = {
    #   url = "github:seL4/seL4/17.0.0";
    #   flake = false;
    # };

    # Firmware sources
    xilinx-embeddedsw-src = {
      url = "github:Xilinx/embeddedsw/xilinx_v2026.2";
      flake = false;
    };
    xilinx-atf-src = {
      url = "github:Xilinx/arm-trusted-firmware/xilinx-v2026.1";
      flake = false;
    };
    xilinx-uboot-src = {
      url = "github:Xilinx/u-boot-xlnx/xilinx-v2026.1";
      flake = false;
    };
    opensbi-src = {
      url = "github:riscv-software-src/opensbi/v1.9";
      flake = false;
    };

    # Python dependencies not in nixpkgs
    guardonce-src = {
      url = "github:cgmb/guardonce/v2.4.0";
      flake = false;
    };
    concurrencytest-src = {
      url = "github:cgoldberg/concurrencytest/0.1.12";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
      ...
    }@inputs:
    let
      # Single source of truth for versions across all derivations
      versions = {
        seL4 = "17.0.0";
        capDL-tool = "1.0.0.1";
        camkes = "3.13.1";
        microkit = "2.4.0";
        microkitCargoHash = "sha256-/0bLPM0SZ90lRHLXEpYWGaJgbBzi1i0Ir338t2S+WhQ=";
        xilinx-embeddedsw = "2026.2";
        xilinx-atf = "xilinx-v2026.1";
        xilinx-uboot = "xilinx-v2026.1";
        opensbi = "1.9";
        guardonce = "2.4.0";
        concurrencytest = "0.1.12";
      };
    in
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            self.overlays.default
          ];
        };

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

        capDLInjectorOverlay = _final: _prev: {
          inherit (self.packages.${system}) capDL-tool;
        };

        #
        ### Custom cross-compilation Environments
        #
        pkgsCross =
          nixpkgs.lib.attrsets.genAttrs
            [
              "aarch64-unknown-linux-gnu"
              "aarch64-unknown-none-elf"
              "armv7l-unknown-linux-gnueabihf"
              "armv7l-unknown-none-eabihf"
              "i686-unknown-none-elf"
              "microblazeel-none-elf"
              "riscv32-unknown-none-elf"
              "riscv64-unknown-linux-gnu"
              "riscv64-unknown-none-elf"
              "x86_64-unknown-none-elf"
            ]
            (
              config:
              import nixpkgs {
                inherit system;
                crossSystem = { inherit config; };
                overlays = [
                  self.overlays.default
                  capDLInjectorOverlay
                ];
              }
            );

        manifests = import ./nix/manifests.nix {
          inherit pkgs inputs;
        };

        packages = import ./nix/packages.nix {
          inherit
            self
            system
            pkgs
            pkgsCross
            inputs
            versions
            manifests
            ;
        };
      in
      {
        inherit packages;

        devShells = import ./nix/devshells.nix {
          inherit pkgs;
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
          in
          (filterAttrs (n: _v: n != "default") packages) // checks;
      }
    )
    // {
      # declare overlay with added deps, i. e. the python packages not available in official nixpkgs
      overlays.default = import ./overlay.nix {
        inherit inputs versions;
      };

      # for CI
      ciJobs =
        let
          inherit (nixpkgs) lib;
        in
        {
          checks = lib.attrsets.recurseIntoAttrs (self.checks or { });
          homeConfigurations = lib.attrsets.recurseIntoAttrs (
            lib.attrsets.mapAttrs (_name: value: value.activationPackage) (self.homeConfigurations or { })
          );
          nixosConfigurations = lib.attrsets.recurseIntoAttrs (
            lib.attrsets.mapAttrs (_name: value: value.config.system.build.toplevel) (
              self.nixosConfigurations or { }
            )
          );
          packages = lib.attrsets.recurseIntoAttrs (self.packages or { });
        };
    };
}
