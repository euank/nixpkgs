{ lib, stdenv, fetchFromGitHub, gzip }:

stdenv.mkDerivation rec {
  pname = "ndppd";
  version = "20200522";

  src = fetchFromGitHub {
    owner = "DanielAdolfsson";
    repo = "ndppd";
    rev = "e01d67a864bbeeb8e15f35ad955aecafa52e4c3d";
    sha256 = "sha256-2Ml2Yigolv2BWC8eROzewUsOmVUGCV47rphllyC6hP4=";
  };

  nativeBuildInputs = [ gzip ];

  makeFlags = [
    "PREFIX=$(out)"
  ];

  preConfigure = ''
    substituteInPlace Makefile --replace /bin/gzip gzip
  '';

  postInstall = ''
    mkdir -p $out/etc
    cp ndppd.conf-dist $out/etc/ndppd.conf
  '';

  meta = with lib; {
    description = "A daemon that proxies NDP (Neighbor Discovery Protocol) messages between interfaces";
    homepage = "https://github.com/DanielAdolfsson/ndppd";
    license = licenses.gpl3;
    platforms = platforms.linux;
    maintainers = with maintainers; [ fadenb globin ];
  };
}
