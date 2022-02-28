{ lib, clangStdenv, fetchFromGitHub, fetchurl, fetchpatch, fetchgit
, python3Packages, ninja, pkg-config, protobuf, zinnia, qt5, fcitx5
, jsoncpp, which, gtk2, unzip, abseil-cpp, breakpad }:
let
  inherit (python3Packages) python gyp six;
  zipcode_rel = "202011";
  jigyosyo = fetchurl {
    url = "https://osdn.net/projects/ponsfoot-aur/storage/mozc/jigyosyo-${zipcode_rel}.zip";
    sha256 = "j7MkNtd4+QTi91EreVig4/OV0o5y1+KIjEJBEmLK/mY=";
  };
  x-ken-all = fetchurl {
    url =
      "https://osdn.net/projects/ponsfoot-aur/storage/mozc/x-ken-all-${zipcode_rel}.zip";
    sha256 = "ExS0Cg3rs0I9IOVbZHLt8UEfk8/LmY9oAHPVVlYuTPw=";
  };

in clangStdenv.mkDerivation rec {
  pname = "fcitx5-mozc";
  version = "2.26.4660.102";

  src = fetchFromGitHub {
    owner = "fcitx";
    repo = "mozc";
    rev = "cf8d220b7d9b4fb3ca4345bf459f6680756e1658";
    sha256 = "sha256-17mGQ7wioLsMKXBHWwhF04wBJSnPbu/KjNBUKXKfYLM=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ ninja python pkg-config qt5.wrapQtAppsHook six which unzip ];

  buildInputs = [ protobuf zinnia qt5.qtbase fcitx5 gtk2 ];

  postUnpack = ''
    unzip ${x-ken-all} -d $sourceRoot/src/
    unzip ${jigyosyo} -d $sourceRoot/src/
  '';

  # Copied from https://github.com/archlinux/svntogit-community/blob/packages/fcitx5-mozc/trunk/PKGBUILD
  configurePhase = ''
    cd src
    export GYP_DEFINES="document_dir=$out/share/doc/mozc use_libzinnia=1 use_libprotobuf=1 use_libabseil=1"

    # disable fcitx4
    rm unix/fcitx/fcitx.gyp

    # gen zip code seed
    PYTHONPATH="$PWD:$PYTHONPATH" python dictionary/gen_zip_code_seed.py --zip_code="x-ken-all.csv" --jigyosyo="JIGYOSYO.CSV" >> data/dictionary_oss/dictionary09.txt

    # use libstdc++ instead of libc++
    sed "/stdlib=libc++/d;/-lc++/d" -i gyp/common.gypi

    # run gyp
    python build_mozc.py gyp --gypdir=${gyp}/bin --server_dir=$out/lib/mozc
  '';

  buildPhase = ''
    python build_mozc.py build -c Release \
      server/server.gyp:mozc_server \
      gui/gui.gyp:mozc_tool \
      unix/fcitx5/fcitx5.gyp:fcitx5-mozc
  '';

  installPhase = ''
    export PREFIX=$out
    export _bldtype=Release
    ../scripts/install_server
    install -d $out/share/licenses/fcitx5-mozc
    head -n 29 server/mozc_server.cc > $out/share/licenses/fcitx5-mozc/LICENSE
    install -m644 data/installer/*.html $out/share/licenses/fcitx5-mozc/
    install -d $out/share/fcitx5/addon
    install -d $out/share/fcitx5/inputmethod
    install -d $out/lib/fcitx5
    ../scripts/install_fcitx5
  '';

  meta = with lib; {
    description = "Fcitx5 Module of A Japanese Input Method for Chromium OS, Windows, Mac and Linux (the Open Source Edition of Google Japanese Input)";
    homepage = "https://github.com/fcitx/mozc";
    license = licenses.bsd3;
    maintainers = with maintainers; [ berberman ];
    platforms = platforms.linux;
  };
}
