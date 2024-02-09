{ lib
, stdenvNoCC
, cacert
, git
, git-repo
, nukeReferences

  # arguments of interest
, hash
, name ? "repo-tool-source"
, version ? "unknown"
, repoUrl
}:

stdenvNoCC.mkDerivation {
  pname = name;
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [ cacert git git-repo nukeReferences ];

  installPhase = ''
    runHook preInstall
    mkdir -- $out home
    export HOME="$PWD/home"
    cd $out
    repo init --manifest-url ${lib.strings.escapeShellArg repoUrl} --no-repo-verify
    repo sync
    rm --force --recursive -- .repo
    runHook postInstall
  '';

  dontFixup = true;

  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = hash;
}
