{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    mach-nix.url = "github:DavHau/mach-nix";
    # mach-nix.inputs.nixpkgs.follows = "nixpkgs";
    # sel4-src.url = "github:seL4/seL4";
    # sel4-src.flake = false;
  };

  outputs = { self, nixpkgs, utils, ... } @ inputs: utils.lib.eachSystem ["x86_64-linux"] (system:
    let
      pkgs = import nixpkgs { inherit system; };
      pythonPackages = pkgs.python39Packages;
      mach-nix = inputs.mach-nix.lib.${system};

      seL4-configs = {
        "AARCH64_verified" = pkgs.pkgsCross.aarch64-embedded;
        "ARM_HYP_verified" = pkgs.pkgsCross.arm-embedded;
        "ARM_MCS_verified" = pkgs.pkgsCross.arm-embedded;
        "ARM_verified" = pkgs.pkgsCross.arm-embedded;
        #"RISCV64_MCS_verified" = pkgs.pkgsCross.riscv64-embedded;
        #"RISCV64_verified" = pkgs.pkgsCross.riscv64-embedded;
        "X64_verified" = pkgs;
      };
    in
    rec {

      /* build a kernel */
      lib.buildKernel = { pkgs, pkgsTarget, name ? "seL4", config, version, src }: pkgsTarget.stdenv.mkDerivation {
        pname = name;
        inherit src version;
        nativeBuildInputs = with pkgs; [
          pkgsTarget.stdenv.cc
          cmake # build tools
          ninja # build tools
          libxml2 # xmllint
          dtc #
          self.packages.${system}.python-env
          #(python3.withPackages (ps: with ps; [ setuptools six jinja2 future ply pyyaml libfdt ]))
        ];
        patchPhase = "patchShebangs tools"; # fix /bin/bash et al.
        cmakeFlags = [
          #"-DKernelSel4Arch=arm"
          "-DCMAKE_MAKE_PROGRAM=ninja"
          "-DCMAKE_ASM_COMPILER=${pkgsTarget.stdenv.cc.targetPrefix}gcc"
          "-C../configs/${config}.cmake"
        ];
        installPhase = ''
          cp --recursive -- . $out/
        '';
        dontFixup = true;
      };

      packages = rec {
        # all-in seL4 + CAmkES python environment
        python-env = mach-nix.mkPython {
          requirements = ''
            camkes-deps
            sel4-deps
            ordered_set
            setuptools # for `import pkg_resource`
          '';
        };
      } // (pkgs.lib.mapAttrs'
        (config: pkgsTarget: {
          name = "seL4-${config}";
          value = lib.buildKernel rec {
            inherit config pkgs pkgsTarget;
            version = "12.1.0";
            src = pkgs.fetchFromGitHub rec {
              owner = "moritz-meier"; #"seL4";
              repo = "seL4";
              rev = "d90fada";
              sha256 = "sha256-Scoxxf8iS/oYJJWS8YDtsR7UCmbKLSK25OMWIEgHd6c=";
            };
          };
        })
        seL4-configs);

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
          packages.python-env
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

      checks = packages;
    });
}
