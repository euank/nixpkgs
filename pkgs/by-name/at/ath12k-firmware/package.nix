{
  lib,
  fetchFromGitHub,
  fetchgit,
  python3,
  stdenv,
}:

let
  qca-swiss-army-knife = fetchFromGitHub {
    owner = "qca";
    repo = "qca-swiss-army-knife";
    rev = "7a1463a4423f4679d6cb7f34c26af9a2076e31f9";
    hash = "sha256-hSkGIjVCh7hhSghayYCeW1rYqGz4MZODeILucbwibrI=";
  };
in
stdenv.mkDerivation {
  pname = "ath12k-firmware";
  version = "2024-10-21";

  src = fetchgit {
    url = "https://git.codelinaro.org/clo/ath-firmware/ath12k-firmware.git";
    rev = "3ee26f4705a4bf8c3ee1c935f5d21bad9b6d2612";
    hash = "sha256-mz6ukOMRSDstNW7lXcokEnoIX6ve/1Ld83J04ikXukM=";
  };

  nativeBuildInputs = [
    python3
  ];

  buildPhase = "true";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/firmware
    python3 ${qca-swiss-army-knife}/tools/scripts/ath12k/ath12k-fw-repo --install $out/lib/firmware

    runHook postInstall
  '';

  meta = with lib; {
    description = "ath12k firmware for the kernel";
    homepage = "https://wireless.docs.kernel.org/en/latest/en/users/drivers/ath12k.html";
    license = licenses.unfree;
    maintainers = with maintainers; [ euank ];
    platforms = platforms.linux;
  };
}
