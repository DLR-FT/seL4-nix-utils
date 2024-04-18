{ stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation {
  pname = "microkit-sdk";
  version = "unstable-2024-04-18";

  src = fetchurl {
    url = "https://trustworthy.systems/Downloads/microkit_tutorial/sdk-linux-x64.tar.gz";
    hash = "sha256-IBVOiEzbgkAFiAvDjwODfEYsLxMPxrKAHtp4MPLPsl8=";
  };

  installPhase = ''
    mkdir -- $out
    mv bin board doc $out/
  '';
}
