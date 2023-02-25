{ lib, stdenv, fetchFromGitHub, gzip }:

stdenv.mkDerivation rec {
  pname = "ndppd";
  version = "20231211";

  src = fetchFromGitHub {
    owner = "DanielAdolfsson";
    repo = "ndppd";
    rev = "4f0301f94345c92b723392ed2d73f04f910e6c30";
    sha256 = "sha256-Hp3VxK+nQukWl7Plq72cFPfYfFhj+LgZun4NcTYRm4g=";
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
    maintainers = with maintainers; [ fadenb ];
    mainProgram = "ndppd";
  };
}
