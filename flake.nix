{
  inputs = {
    utils.url = "git+https://github.com/numtide/flake-utils";
    mach-nix.url = "github:DavHau/mach-nix";
    mach-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, utils, ... } @ inputs: utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      pythonPackages = pkgs.python39Packages;
      mach-nix = inputs.mach-nix.lib.${system};
    in
    rec {
      packages = rec {
        python-env = mach-nix.mkPython {
          requirements = ''
            camkes-deps
            sel4-deps
            ordered_set
            setuptools # for `import pkg_resource`
          '';
        };
      };

      devShell = (pkgs.mkShell.override { stdenv = pkgs.gcc8Stdenv; }) {
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
    });
}
