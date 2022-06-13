{
  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-21.11";
    utils.url = "git+https://github.com/numtide/flake-utils";
    # TODO remove this once https://github.com/seL4/capdl/pull/37 is fixed
    # as a very old ghc802 is required, we have to propagate the nixos-18.09 branch 
    # as source to stack, which is internally ran by the seL4 build
    old-nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-18.09";
    old-nixpkgs.flake = false;
  };

  outputs = { self, nixpkgs, utils, nur, ... } @ inputs: utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      # ghc802 = (import inputs.old-nixpkgs { inherit system; }).haskell.compiler.ghc802;
      pythonPackages = pkgs.python39Packages;
    in
    rec {

      packages = rec {
        camkes-deps = with pythonPackages; buildPythonPackage rec {
          pname = "camkes-deps";
          version = "0.7.3";
          src = fetchPypi {
            inherit pname version;
            sha256 = "sha256-dvyp1TbqIw5v8DFb1YMkKFWhOGql90e8ceUBtp46XIU=";
          };
          propagatedBuildInputs = [
            aenum
            hypothesis
            ordered-set
            pyfdt
            plyplus
            sel4-deps
          ];
        };

        sel4-deps = with pythonPackages; buildPythonPackage rec {
          pname = "sel4-deps";
          version = "0.3.1";
          src = fetchPypi {
            inherit pname version;
            sha256 = "sha256-ubSn2l3Zd2xH4k2+brPNwn53hdfi4Qtbt4qzxB7Zsic=";
          };
          # TODO this is a hack, that will potentially break things
          preBuild = ''
            cat setup.py
            substituteInPlace setup.py \
              --replace "'autopep8==1.4.3'," "'autopep8==${autopep8.version}',"
          '';
          propagatedBuildInputs = [
            autopep8
            bs4
            cmake-format-custom
            concurrencytest
            future
            guardonce
            jinja2
            jsonschema
            libarchive-c
            lxml
            orderedset
            pexpect
            ply
            psutil
            pyaml
            pycparser
            pyelftools
            pyfdt
            sh
            six
          ];
        };

        ### transitive dep of camkes-deps
        bs4 = with pythonPackages; buildPythonPackage rec {
          pname = "bs4";
          version = "0.0.1";
          src = fetchPypi {
            inherit pname version;
            sha256 = "sha256-NuzqH9fMXAxuSh/wdd8m1Q2mR7dTdmJswYbiISiG3To=";
          };
          propagatedBuildInputs = [ beautifulsoup4 ];
        };

        cmake-format-custom = with pythonPackages; buildPythonPackage rec {
          pname = "cmake_format"; # TODO WTF, why is it a low-dash?
          version = "0.4.5";
          src = fetchPypi {
            inherit pname;
            inherit version;
            sha256 = "sha256-FmAkCMd0zZiez6JYg95MLbrJN+OJC3Nb5Kq3b5ZHh1o=";
          };
          doCheck = false; # TODO fix this
        };

        concurrencytest = with pythonPackages; buildPythonPackage rec {
          pname = "concurrencytest";
          version = "0.1.2";
          src = fetchPypi {
            inherit pname version;
            sha256 = "sha256-ZKnFtc25lJo3X8xeEUqCGA9qB8waAm05ViMK7PmAwtg=";
          };
          propagatedBuildInputs = [ subunit ];
        };

        guardonce = with pythonPackages; buildPythonPackage rec {
          pname = "guardonce";
          version = "2.4.0";
          src = fetchPypi {
            inherit pname version;
            sha256 = "sha256-x4keUZod3l0uR94pJ/VUtdHMTrtvDT6vuVvAmlxgJ2s=";
          };
          doCheck = false; # TODO remove this
        };

        pyfdt = with pythonPackages; buildPythonPackage rec {
          pname = "pyfdt";
          version = "0.3";
          src = fetchPypi {
            inherit pname version;
            sha256 = "sha256-YWAcIAX/OUolpshMbaIIi7+IgygDhADSfk7rGwS59PA=";
          };
        };
      };

      devShell = pkgs.mkShell {
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
          gcc8
          gcc-arm-embedded-8

          # CAmkES
          stack

          # both
          (python3.withPackages (ps: with ps; [ packages.camkes-deps ]))
        ];
        shellHook = ''
          export NIX_PATH=nixpkgs=${inputs.old-nixpkgs}:$NIX_PATH
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
