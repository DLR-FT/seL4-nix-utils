{ lib, stdenvNoCC, cacert, git, git-repo, nukeReferences }:

let inherit (lib.strings) escapeShellArg;

in lib.makeOverridable ({ url, rev, name ? "source", hash
  # Problem
  #
  # `repo` allows for the manifest to just specify a branch, defaulting to the latest commit.
  # This is nice to avoid frequent manifest updates, however, it destroys determinism. Running
  # `repo sync` on the very same commit of the manifest may create abitrarily different results on
  # any given day.
  #
  # Solution
  #
  # A date is provided that describes a fixed point in time. For all repositories fetched by the
  # `repo` tool, the latest commit before that given date is checked out. The date defaults to
  # the date of the last commit in the manifest repo, but the user can provided any other date
  # instead.
  #
  # This is reasonably reproducible, but still leaky: an amended commit may have changed contents
  # without a changed date. Also, force pushes to the repo will yield different results. Both
  # of these cases are however caught by the fixed output derivation hash, and are present with
  # normal git checkouts as well.
  , latestCommitTimestamp ? null }@args:

  stdenvNoCC.mkDerivation {
    inherit name;
    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [ cacert git git-repo ];

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
      MANIFEST_TIMESTAMP=${
        if latestCommitTimestamp != null then
          escapeShellArg latestCommitTimestamp
        else
          "$(git show --no-patch --format=%cI)"
      }
      echo -e "Cutoff date is \033[1;4m''${MANIFEST_TIMESTAMP}\033[0m"
      echo "Manifest is checked out at"
      git-describe-tip
      popd > /dev/null

      repo sync

      find . -not \( -path ./.repo -prune \) -name .git -type l -printf '%h\0' |
        while IFS= read -r -d ''' GIT_REPO_ROOT; do
          pushd "$GIT_REPO_ROOT" > /dev/null

          echo "''${PWD##*/}: is checked out at"
          git-describe-tip

          CUTOFF_EPOCH="$(date --date "$MANIFEST_TIMESTAMP" '+%s')"
          AUTHOR_EPOCH="$(git show --no-patch --format='%at')"
          COMMIT_EPOCH="$(git show --no-patch --format='%ct')"
          if [ "$AUTHOR_EPOCH" -gt "$CUTOFF_EPOCH" ] || [ "$COMMIT_EPOCH" -gt "$CUTOFF_EPOCH" ];
          then
            echo -e "HEAD is younger than cutoff date, \033[0;31mrewinding history\033[0m"

            git checkout --quiet \
              "$(git rev-list -n 1 --first-parent --before="$MANIFEST_TIMESTAMP" HEAD)"

            echo "now checked out at"
            git-describe-tip
          fi
          popd > /dev/null
        done

      rm --force --recursive -- .repo
      find . -xtype l -delete
      runHook postInstall
    '';

    dontFixup = true;

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = hash;
  })
