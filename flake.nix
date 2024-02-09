{
  inputs = {
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils, ... } @ inputs: utils.lib.eachSystem [ "x86_64-linux" ] (system:
    let
      pkgs = import nixpkgs { inherit system; };
    in
    rec {
      packages = rec {
        # python dependencies

        guardonce = pkgs.python3Packages.callPackage pkgs/guardonce.nix { };
        pyfdt = pkgs.python3Packages.callPackage pkgs/pyfdt.nix { };

        python-seL4-deps = pkgs.python3Packages.callPackage pkgs/python-seL4-deps.nix {
          inherit (self.packages.${system}) guardonce pyfdt;
        };

        #
        ### seL4 Kernel Flavours
        #
        seL4-kernel-arm-hyp = pkgs.callPackage pkgs/seL4-kernel.nix {
          inherit python-seL4-deps;
          config = "ARM_HYP_verified";
        };

        seL4-kernel-arm-mcs = pkgs.callPackage pkgs/seL4-kernel.nix {
          inherit python-seL4-deps;
          config = "ARM_MCS_verified";
        };

        seL4-kernel-arm = pkgs.callPackage pkgs/seL4-kernel.nix {
          inherit python-seL4-deps;
          config = "ARM_verified";
        };

        seL4-kernel-riscv64-mcs = pkgs.callPackage pkgs/seL4-kernel.nix {
          inherit python-seL4-deps;
          config = "RISCV64_MCS_verified";
        };

        seL4-kernel-riscv64 = pkgs.callPackage pkgs/seL4-kernel.nix {
          inherit python-seL4-deps;
          config = "RISCV64_verified";
        };

        seL4-kernel-x64 = pkgs.callPackage pkgs/seL4-kernel.nix {
          inherit python-seL4-deps;
          config = "X64_verified";
        };

        #
        ### seL4 kernel + userspace flavours
        #
        seL4-arm-hyp = pkgs.callPackage pkgs/seL4.nix {
          inherit python-seL4-deps;
          config = "ARM_HYP_verified";
          extraCmakeFlags = [
            "-DPLATFORM=zynq7000"
            "-DRELEASE=FALSE"
            "-DVERIFICATION=FALSE"
          ];
        };

        seL4-arm-mcs = pkgs.callPackage pkgs/seL4.nix {
          inherit python-seL4-deps;
          config = "ARM_MCS_verified";
          extraCmakeFlags = [
            "-DPLATFORM=zynq7000"
            "-DRELEASE=FALSE"
            "-DVERIFICATION=FALSE"
          ];
        };

        seL4-arm = pkgs.callPackage pkgs/seL4.nix {
          inherit python-seL4-deps;
          config = "ARM_verified";
          extraCmakeFlags = [
            "-DPLATFORM=zynq7000"
            "-DRELEASE=FALSE"
            "-DVERIFICATION=FALSE"
          ];
        };

        # These two fail to link

        # seL4-riscv64-mcs = pkgs.callPackage pkgs/seL4.nix {
        #   inherit python-seL4-deps;
        #   config = "RISCV64_MCS_verified";
        #   extraCmakeFlags = [
        #     "-DPLATFORM=hifive"
        #     "-DRELEASE=FALSE"
        #     "-DVERIFICATION=FALSE"
        #   ];
        # };
        # seL4-riscv64 = pkgs.callPackage pkgs/seL4.nix {
        #   inherit python-seL4-deps;
        #   config = "RISCV64_verified";
        #   extraCmakeFlags = [
        #     "-DPLATFORM=hifive"
        #     "-DRELEASE=FALSE"
        #     "-DVERIFICATION=FALSE"
        #   ];
        # };

        seL4-x64 = pkgs.callPackage pkgs/seL4.nix {
          inherit python-seL4-deps;
          config = "X64_verified";
          extraCmakeFlags = [
            "-DPLATFORM=pc99"
            "-DRELEASE=FALSE"
            "-DVERIFICATION=FALSE"
          ];
        };


        seL4-repo-tool-source = pkgs.callPackage pkgs/repo-tool-fetcher.nix {
          repoUrl = "https://github.com/seL4/sel4test-manifest.git";
          hash = "sha256-6i64uyQvrv2gLOKKyNsLhaz0t+DKmhumvtwPcj6EEL8=";
        };
      };

      devShells.default = (pkgs.mkShell.override { stdenv = pkgs.gcc8Stdenv; }) {
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
          packages.python-seL4-deps
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
      hydraJobs = (nixpkgs.lib.filterAttrs (n: _: n != "default") packages) // checks;
    });
}
