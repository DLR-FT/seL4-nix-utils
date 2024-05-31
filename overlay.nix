final: prev: {
  # generated using
  #
  # nix run nixpkgs#cabal2nix -- --maintainer wucke13 --subpath capDL-tool --dont-fetch-submodules https://github.com/seL4/capdl.git > pkgs/capdl.nix
  capDL-tool =
    let
      hsPkgs = final.haskellPackages.override {
        overrides = final': prev': {
          MissingH = final.haskell.lib.overrideCabal prev'.MissingH {
            version = "1.5.0.1";
            sha256 = "sha256-yy+kpipgnsa8+i6raubTTG9b+6Uj/tjcDAVbMXZzIjE=";
            revision = "1";
            editedCabalFile = "sha256-9mLTXlTu5Va/bxqOxDGXKJhUMmiehE5hGwLpWBN7UaI=";
          };
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
  microkit-sdk-bin = prev.callPackage pkgs/microkit-sdk-bin.nix { };


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
}
