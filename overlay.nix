final: prev: {
  # generated using
  #
  # nix run nixpkgs#cabal2nix -- --maintainer wucke13 --subpath capDL-tool --dont-fetch-submodules https://github.com/seL4/capdl.git --revision 0.6.0 > pkgs/capDL-tool.nix
  capDL-tool =
    let
      hsPkgs = final.haskell.packages.ghc94.override {
        overrides = final': prev': {
          MissingH = final'.callHackage "MissingH" "1.5.0.1" { };
          network = final'.callHackage "network" "3.1.4.0" { };
          base-compat = final'.callHackage "base-compat" "0.12.3" { };
        };
      };
    in
    hsPkgs.callPackage pkgs/capDL-tool.nix { };

  # Fetcher that uses Google's repo tool. Kinf of cursed, had some issues with determinism.
  # Hopefully now it's fully deterministic.
  # https://android.googlesource.com/tools/repo
  fetchGoogleRepoTool = prev.callPackage pkgs/fetch-google-repo-tool.nix { };

  # microkit
  microkit-sdk = prev.callPackage pkgs/microkit-sdk.nix { };

  # overlay python packages
  pythonPackagesOverlays = (prev.pythonPackagesOverlays or [ ]) ++ [
    (python-final: python-prev: {
      guardonce = python-final.callPackage pkgs/guardonce.nix { };

      pyfdt = python-final.callPackage pkgs/pyfdt.nix { };

      concurrencytest = python-final.callPackage pkgs/concurrencytest.nix { };

      seL4-deps = python-final.callPackage pkgs/seL4-deps.nix {
        inherit (python-final) guardonce pyfdt;
      };

      camkes-deps = python-final.callPackage pkgs/camkes-deps.nix {
        inherit (python-final) pyfdt seL4-deps concurrencytest;
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
      ...
    }@args:
    (final.callPackage pkgs/seL4-kernel.nix {
      inherit verifiedConfig;
      inherit extraVerifiedConfigs;
      inherit extraCmakeFlags;
    }).overrideAttrs
      (
        old:
        removeAttrs args [
          "verifiedConfig"
          "extraVerifiedConfigs"
          "extraCmakeFlags"
        ]
      )
  );
}
