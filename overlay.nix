final: prev: {
  # microkit
  microkit-sdk-bin = prev.callPackage pkgs/microkit-sdk-bin.nix { };

  pyoxidizer = prev.callPackage pkgs/pyoxidizer.nix {
    pythonPackages = prev.python3Packages;
  };


  # overlay python packages
  pythonPackagesOverlays = (prev.pythonPackagesOverlays or [ ]) ++ [
    (python-final: python-prev: {
      guardonce = python-final.callPackage pkgs/guardonce.nix { };

      pyfdt = python-final.callPackage pkgs/pyfdt.nix { };

      pyoxidizer = python-prev.toPythonModule (final.pyoxidizer.override {
        pythonPackages = python-prev;
      });

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

  # Fetcher that uses Google's repo tool. Kinf of cursed, had some issues with determinism.
  # Hopefully now it's fully deterministic.
  # https://android.googlesource.com/tools/repo
  fetchGoogleRepoTool = prev.callPackage pkgs/fetch-google-repo-tool.nix { };
}
