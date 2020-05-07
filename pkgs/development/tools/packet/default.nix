# This file was generated by https://github.com/kamilchm/go2nix v1.2.1
{ stdenv, buildGoPackage, fetchgit }:

buildGoPackage rec {
  pname = "packet";
  version = "v2.2.2";

  goPackagePath = "github.com/ebsarr/packet";

  src = fetchgit {
    rev = version;
    url = "https://github.com/ebsarr/packet";
    sha256 = "18n8f2rlab4icb28k1b9gnh30zy382v792x07fmcdqq4nkw6wvwf";
  };

  goDeps = ./deps.nix;

  meta = {
    description = "a CLI tool to manage packet.net services";
    homepage = "https://github.com/ebsarr/packet";
    license = stdenv.lib.licenses.mit;
    maintainers = [ stdenv.lib.maintainers.grahamc ];
    platforms = stdenv.lib.platforms.unix;
  };
}
