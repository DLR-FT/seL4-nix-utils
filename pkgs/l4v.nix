{
  lib,
  hostPlatform, # cross compilation does not make sense for this package
  stdenvNoCC,
  fetchGoogleRepoTool,
  fetchurl,
  which,
  isabelle,
  cmake,
  curl,
  mlton,
  ninja,
  pkgsCross,
  python3Packages,
  fontconfig,
  openjdk_headless,
  autoPatchelfHook,
  jdk21,
  libsecret,
  nss,
  nspr,
  xorg,
}:

# TODO notes
#
# ./isabelle/Admin/components/components.sha1 contains the sha sums of all components
# ./isabelle/Admin/components/main lists all the components to be installed
# isabelle needs to be run from a hg/git dir, otherwise https://isabelle.in.tum.de/repos/isabelle/rev/0106c89fb71f?revcount=120
#   possibly ISABELLE_ID is useful? -> echo ID > etc/ISABELLE_ID

let
  # list of component files required by this isabelle distribution
  getRequiredComponents =
    src:
    let
      inherit (builtins) map readFile;
      inherit (lib.lists) filter;
      inherit (lib.strings) concatLines hasPrefix splitString;

      # a filter that matches everything except for empty strings and strings starting `#`
      removeCommentsAndBlanks = (x: x != "" && !(hasPrefix "#" x));

      componentFiles = [
        "bundled"
        "main"
        "cakeml"
        "ci-extras"
        "optional"
      ] ++ lib.lists.optional (hostPlatform.isLinux) "bundled-linux";

      componentsStr = concatLines (
        map (f: readFile (src + "/isabelle/Admin/components/${f}")) componentFiles
      );
    in
    filter removeCommentsAndBlanks (splitString "\n" componentsStr);

  # attrset of all component filenames and the respective path to the nix store
  getAllComponents =
    src:
    let
      inherit (builtins) map listToAttrs readFile;
      inherit (lib.attrsets) mapAttrs';
      inherit (lib.lists) filter;
      inherit (lib.strings) removeSuffix splitString;

      # array of lines each consisting of a sha1 hash and a file name, space seperated
      componentHashLines = lib.strings.splitString "\n" (
        readFile (src + "/isabelle/Admin/components/components.sha1")
      );

      # a list of lists, each inner list with the first element as sha1 and the second as filename
      fileHashTuples = map (splitString " ") (filter (x: x != "") componentHashLines);

      # an attrset mapping filename to sha1 hash
      componentSha1Hashes = listToAttrs (
        map (t: {
          name = builtins.elemAt t 1;
          value = builtins.elemAt t 0;
        }) fileHashTuples
      );

      # function to fetch one component identified by filename and sha1
      fetchComponent =
        filename: sha1:
        fetchurl {
          url = "https://isabelle.sketis.net/components/${filename}";
          inherit sha1;
        };
    in
    mapAttrs' (name: sha1: {
      # the component files refer to the files without the `.tar.gz` suffix
      name = removeSuffix ".tar.gz" name;
      value = fetchComponent name sha1;
    }) componentSha1Hashes;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "L4.verified";
  version = "13.0.0";

  src = fetchGoogleRepoTool {
    url = "https://github.com/seL4/verification-manifest";
    rev = "2b434d1957eba420782f10f90e58f0b93ee3a4b7"; # 2024-10-11
    manifest = "${finalAttrs.version}.xml";
    hash = "sha256-GTjofiun3TWlKdHRegWJNIitRzcZTGuSZQG1tmLpBg0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    which
    isabelle
    mlton
    openjdk_headless
    fontconfig

    cmake
    ninja

    curl # for isabelle to fetch dependencies

    # compilers
    pkgsCross.aarch64-embedded.stdenv.cc.bintools.bintools
    pkgsCross.aarch64-embedded.stdenv.cc.cc
    pkgsCross.arm-embedded.stdenv.cc.bintools.bintools
    pkgsCross.arm-embedded.stdenv.cc.cc
    pkgsCross.riscv64-embedded.stdenv.cc.bintools.bintools
    pkgsCross.riscv64-embedded.stdenv.cc.cc
  ];

  buildInputs =
    [
      jdk21 # for libjli.so
      libsecret # for libsecret-1.so.0
      xorg.libxkbfile # for libxkbfile.so.1
      nspr # for libnspr4.so
      nss # for libnss3.so and libnssutil3.so and libsmime3.so
      # xorg.libXext # for libXext.so.6
    ]
    # we autoPatchelf a downloaded jdk21, likely it needs all these for the .so files
    ++ jdk21.buildInputs;

  env.HOME = placeholder "out";
  env.USER_HOME = "${placeholder "out"}/isabelle-home";
  env.JAVA_HOME = jdk21;

  dontUseCmakeConfigure = true;

  # preConfigure = ''
  #   rm --force --recursive -- isabelle
  #   ln --force --symbolic -- ${isabelle} isabelle
  # '';

  prePatch = ''
    patchShebangs .
  '';

  autoPatchelfIgnoreMissingDeps = [
    "libdrm.so.2" # used by VSCode, which is irrelevant for us
    "libgbm.so.1" # used by VSCode, which is irrelevant for us
  ];

  preBuild = ''
    cd l4v

    mkdir --parent -- "$USER_HOME"/.isabelle/{etc,contrib}
    cp -- misc/etc/settings "$USER_HOME/.isabelle/etc/"

    # link prefetched components to where isabelle expectes them
    ${lib.strings.concatLines (
      let
        allComponents = getAllComponents finalAttrs.src;
        requiredComponents = getRequiredComponents finalAttrs.src;
      in
      builtins.map (
        component:
        let
          escapedComponentPath = lib.strings.escapeShellArg allComponents.${component};
        in
        ''
          ln --symbolic -- ${escapedComponentPath} \
            "$USER_HOME/.isabelle/contrib/"$(stripHash ${escapedComponentPath})
        ''
      ) requiredComponents
    )}

    # unpack the pre-fetched components
    ./isabelle/bin/isabelle components -a

    # autoPachelf the components so that dynamic libraries are found
    autoPatchelf "$USER_HOME"

    # ???
    ./isabelle/bin/isabelle jedit -bf
    ./isabelle/bin/isabelle build -bv HOL
  '';

  buildPhase = ''
    runHook preBuild

    cd proof

    make all

    runHook postBuild
  '';
})
