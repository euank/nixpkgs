{ fetchurl
, stdenv
, postgresql
, pkgconfig
, libiconv
}:
let
  pversion = "2.2";
  # github release version uses x_y instead of x.y
  urlVersion = builtins.replaceStrings ["."] ["_"] pversion;
in stdenv.mkDerivation rec {
  pname = "wal2json";
  version = pversion;

  outputs = [ "out" ];

  src = fetchurl {
    url = "https://github.com/eulerto/wal2json/archive/wal2json_${urlVersion}.tar.gz";
    sha256 = "1dg31az05hfrgyv3s83jc7lp5lnjmkiabj6v72x8djzww577djz2";
  };

  buildInputs = [ postgresql ]
                ++ stdenv.lib.optional stdenv.isDarwin libiconv;
  nativeBuildInputs = [ pkgconfig ];
  dontDisableStatic = true;

  preConfigure = ''
    makeFlags="USE_PGXS=1 datadir=$out/share/postgresql pkglibdir=$out/lib bindir=$out/bin"
  '';
  postConfigure = ''
    mkdir -p $out/bin

    # PGXS's build system assumes it is being installed to the same place as postgresql, and looks
    # for the postgres binary relative to $PREFIX. We gently support this system using an illusion.
    ln -s ${postgresql}/bin/postgres $out/bin/postgres
  '';

  postInstall = ''
    # Teardown the illusory postgres used for building; see postConfigure.
    rm $out/bin/postgres
  '';

  meta = with stdenv.lib; {
    description = "PostgreSQL JSON output plugin for changeset extraction";
    homepage = https://github.com/eulerto/wal2json;
    changelog = "https://github.com/eulerto/wal2json/releases/tag/wal2json_${urlVersion}";
    license = licenses.bsd3;
    maintainers = [ ];
    inherit (postgresql.meta) platforms;
  };
}
