{ lib
, stdenvNoCC
, cacert
, git
, git-repo
, nukeReferences
}:

let
  inherit (lib.strings) escapeShellArg;
in

lib.makeOverridable (
  { url
  , rev
  , name ? "source"
  , hash
  }@args:

  stdenvNoCC.mkDerivation {
    inherit name;
    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [ cacert git git-repo ];

    installPhase = ''
      runHook preInstall
      mkdir -- $out home
      export HOME="$PWD/home"
      cd $out
      repo init --manifest-url=${escapeShellArg url} --no-repo-verify

      pushd .repo/manifests
      git fetch --all --tags
      git checkout ${escapeShellArg rev}
      popd

      repo sync
      rm --force --recursive .repo/{TRACE_FILE,repo,manifests.git/config}
      runHook postInstall
    '';

    dontFixup = true;

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = hash;
  }
)
