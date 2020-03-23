{ lib, buildGoModule, fetchFromGitHub }:

with lib;

buildGoModule rec {
  pname = "k3s";
  version = "1.17.3+k3s1";

  src = fetchFromGitHub {
    owner = "rancher";
    repo = "k3s";
    rev = "v${version}";
    sha256 = "0kvhc514k5lbg29hdwdv27a3cqikn1nf1s21kqb83n205x3ixqmp";
  };

  modSha256 = "0wkp7rrdk2hg28g2pr0hdpqhlijy4myp8x6nyrwk4qn69fi8i475";

  subPackages = [ "." ];

  meta = {
    description = "k3s";
    license = licenses.asl20;
    homepage = https://k3s.io;
    maintainers = [];
    platforms = platforms.linux;
  };
}
