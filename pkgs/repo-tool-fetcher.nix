{ lib
, stdenvNoCC
, cacert
, git
, git-repo
, nukeReferences
}:

lib.makeOverridable (
  { url
  , rev ? (if tag != null then "refs/tags/${tag}" else abort "neither rev nor tag is set")
  , tag ? null
  , name ? "source"
  , hash
  }@args:

  stdenvNoCC.mkDerivation {
    inherit name;
    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [ cacert git git-repo nukeReferences ];

    installPhase = ''
      runHook preInstall
      mkdir -- $out home
      export HOME="$PWD/home"
      cd $out
      repo init \
        --manifest-url=${lib.strings.escapeShellArg url} \
        --manifest-branch=${lib.strings.escapeShellArg rev} \
        --no-repo-verify
      repo sync
      rm --force --recursive -- .repo
      runHook postInstall
    '';

    dontFixup = true;

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = hash;
  }
)
