{ stdenv, fetchFromGitHub, perl }:
# TODO: modules such as libssl

stdenv.mkDerivation rec {
  pname = "inspircd";
  version = "3.6.0";

  src = fetchFromGitHub {
    owner = "inspircd";
    repo = "inspircd";
    sha256 = "1g78qahxaz75c4158p2fid7rzd5dxbgm80gg3fzswsk1pwl1vh9p";
    rev = "v${version}";
  };

  nativeBuildInputs = [ perl ];

  configurePhase = ''
    patchShebangs ./configure make/unit-cc.pl
    ./configure --prefix=$prefix
  '';

  makeFlags = [ "PREFIX=$(out)" ];

  meta = {
    homepage    = "https://www.inspircd.org/";
    description = "A modular C++ IRC server";
    platforms   = stdenv.lib.platforms.unix;
    maintainers = with stdenv.lib.maintainers; [ euank ];
    license     = stdenv.lib.licenses.gpl2Plus;
  };
}
