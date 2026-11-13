{ inputs, versions }:
final: prev: {
  # generated using
  #
  # nix run nixpkgs#cabal2nix -- --maintainer wucke13 --subpath capDL-tool --dont-fetch-submodules https://github.com/seL4/capdl.git --revision 0.6.1 > pkgs/capDL-tool.nix
  capDL-tool = final.haskellPackages.callPackage pkgs/capDL-tool.nix {
    src = inputs.capdl-src;
    version = versions.capDL-tool;
  };

  # Pure Nix workspace assembler replacing fetchGoogleRepoTool
  mkRepoWorkspace = prev.callPackage pkgs/mk-repo-workspace.nix { };

  # microkit
  microkit-sdk = prev.callPackage pkgs/microkit-sdk.nix {
    src = inputs.microkit-src;
    seL4-src = inputs.microkit-seL4-src;
    version = versions.microkit;
    cargoHash = versions.microkitCargoHash;
  };

  # overlay python packages
  pythonPackagesOverlays = (prev.pythonPackagesOverlays or [ ]) ++ [
    (python-final: _python-prev: {
      guardonce = python-final.callPackage pkgs/guardonce.nix {
        src = inputs.guardonce-src;
        version = versions.guardonce;
      };

      concurrencytest = python-final.callPackage pkgs/concurrencytest.nix {
        src = inputs.concurrencytest-src;
        version = versions.concurrencytest;
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

  buildSeL4Kernel = final.lib.makeOverridable (
    {
      verifiedConfig ? null,
      extraVerifiedConfigs ? [ ],
      extraCmakeFlags ? [ ],
      src ? inputs.seL4-src,
      version ? versions.seL4,
      ...
    }@args:
    (final.callPackage pkgs/seL4-kernel.nix {
      inherit
        src
        version
        verifiedConfig
        extraVerifiedConfigs
        extraCmakeFlags
        ;
    }).overrideAttrs
      (
        _old:
        removeAttrs args [
          "verifiedConfig"
          "extraVerifiedConfigs"
          "extraCmakeFlags"
          "src"
          "version"
        ]
      )
  );
}
