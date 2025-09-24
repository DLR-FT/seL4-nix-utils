{
  lib,
  stdenvNoCC,
  cacert,
  git,
  git-repo,
}:

let
  inherit (lib.strings) escapeShellArg;

in
lib.makeOverridable (
  {
    url,
    rev,
    name ? "source",
    hash,
  }:

  stdenvNoCC.mkDerivation {
    inherit name;
    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [
      cacert
      git
      git-repo
    ];

    installPhase = ''
      runHook preInstall

      git-describe-tip(){
        git --no-pager show --no-patch \
          --pretty=format:"%C(bold)%aI  %C(ul)%cI%C(reset)  %h%    %x09%an%x09%s%n"
      }

      mkdir -- "$out" home
      export HOME="$PWD/home"
      cd "$out"
      repo init --manifest-url=${escapeShellArg url} --no-repo-verify

      pushd .repo/manifests > /dev/null
      git fetch --all --tags
      git checkout --quiet ${escapeShellArg rev}
      echo "Manifest is checked out at"
      git-describe-tip
      popd > /dev/null

      repo sync --no-manifest-update

      rm --force --recursive -- .repo
      find . -xtype l -name .git -delete # repo leaves dangling symlinks to .repo behind
      runHook postInstall
    '';

    dontFixup = true;

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = hash;
  }
)
