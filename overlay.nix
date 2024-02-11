final: prev: {
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

  # add repoTool
  repoToolFetcher = prev.callPackage pkgs/repo-tool-fetcher.nix { };
}

