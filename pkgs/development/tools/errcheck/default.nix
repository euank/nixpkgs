{ lib, fetchFromGitHub, buildGoModule }:

buildGoModule rec {
  pname = "errcheck";
  rev = "e62617a91f7bd1abab2cbe7f28966188dd85eee0";
  version = "20220325-${lib.strings.substring 0 7 rev}";

  src = fetchFromGitHub {
    owner = "kisielk";
    repo = "errcheck";
    inherit rev;
    sha256 = "sha256-RoPv6Odh8l9DF1S50pNEomLtI4uTDNjveOXZd4S52c0=";
  };

  vendorSha256 = "sha256-fDugaI9Fh0L27yKSFNXyjYLMMDe6CRgE6kVLiJ3+Kyw=";

  meta = with lib; {
    description = "Program for checking for unchecked errors in go programs";
    homepage = "https://github.com/kisielk/errcheck";
    license = licenses.mit;
    maintainers = with maintainers; [ kalbasit ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
