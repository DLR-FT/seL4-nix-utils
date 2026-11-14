{
  inputs,
  versions ? { },
}:
final: prev:
let
  defaultVersions = import ./nix/versions.nix {
    inherit (final) lib;
    inherit inputs;
  };
  v = defaultVersions // versions;
  workspaces = import ./nix/manifests.nix {
    pkgs = final.buildPackages;
    inherit inputs;
  };
in
{
  # generated using
  #
  # nix run nixpkgs#cabal2nix -- --maintainer wucke13 --subpath capDL-tool --dont-fetch-submodules https://github.com/seL4/capdl.git --revision 0.6.1 > pkgs/capDL-tool.nix
  capDL-tool = final.haskellPackages.callPackage pkgs/capDL-tool.nix {
    src = inputs.capdl-src;
    version = v.capDL-tool;
  };

  # Pure Nix workspace assembler replacing fetchGoogleRepoTool
  mkRepoWorkspace = final.callPackage pkgs/mk-repo-workspace.nix { };

  inherit (workspaces) sel4testWorkspace camkesVmExamplesWorkspace;

  seL4-kernel = final.callPackage pkgs/seL4-kernel.nix {
    src = inputs.seL4-src;
    version = v.seL4;
  };

  seL4-test = final.callPackage pkgs/seL4-test.nix {
    src = final.sel4testWorkspace;
    version = v.seL4;
  };

  seL4-camkes-vm-examples = final.callPackage pkgs/seL4-camkes-vm-examples.nix {
    src = final.camkesVmExamplesWorkspace;
    version = v.camkes;
  };

  # microkit
  microkit-sdk = final.callPackage pkgs/microkit-sdk.nix {
    src = inputs.microkit-src;
    seL4-src = inputs.microkit-seL4-src;
    version = v.microkit;
    cargoOutputHashes = v.microkitCargoOutputHashes;
  };

  # overlay python packages
  pythonPackagesOverlays = (prev.pythonPackagesOverlays or [ ]) ++ [
    (python-final: _python-prev: {
      guardonce = python-final.callPackage pkgs/guardonce.nix {
        src = inputs.guardonce-src;
        version = v.guardonce;
      };

      concurrencytest = python-final.callPackage pkgs/concurrencytest.nix {
        src = inputs.concurrencytest-src;
        version = v.concurrencytest;
      };
    })
  ];

  python3 =
    let
      self = prev.python3.override {
        inherit self;
        packageOverrides = prev.lib.composeManyExtensions final.pythonPackagesOverlays;
      };
    in
    self;

  python3Packages = final.python3.pkgs;
}
