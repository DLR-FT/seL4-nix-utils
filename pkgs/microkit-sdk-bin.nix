{ stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation {
  pname = "microkit-sdk";
  version = "1.3.0";

  src = fetchurl {
    url = "https://github.com/seL4/microkit/releases/download/1.3.0/microkit-sdk-1.3.0-linux-x86-64.tar.gz";
    hash = "sha256-irFoxXcBYHiqNM8CqoIpSgJy0C/fVIDgAaoOJ52Fr2I=";
  };

  installPhase = ''
    mkdir -- $out
    mv bin board doc $out/
  '';
}
