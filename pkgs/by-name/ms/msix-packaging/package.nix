{ lib
, stdenv
, fetchFromGitHub
, icu
, clang
, cmake
, openssl
, zlib
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "msix-packaging";
  version = "1.2-unstable-2025-03-26";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "msix-packaging";
    # not 1.2 tag since we need a few fixes they've committed since, but not
    # tagged
    rev = "efeb9dad695a200c2beaddcba54a52c8320bd135";
    hash = "sha256-2QEsT7yUwJHkKf+/508T9aVber8Nhv8OwNWGJONJfDU=";
  };

  nativeBuildInputs = [
    clang
    cmake
  ];

  postPatch = ''
    # we're using a newer icu than upstream, which requires CXX 17
    substituteInPlace lib/xerces/CMakeLists.txt \
      --replace-fail "set(CMAKE_CXX_STANDARD 14)" "set(CMAKE_CXX_STANDARD 17)"
    substituteInPlace CMakeLists.txt \
      --replace-fail "set(CMAKE_CXX_STANDARD 14)" "set(CMAKE_CXX_STANDARD 17)"

    # nix likes to control output dirs, comment them out
    substituteInPlace CMakeLists.txt \
      --replace-fail 'set(CMAKE_RUNTIME_OUTPUT_DIRECTORY' '# set(CMAKE_RUNTIME_OUTPUT_DIRECTORY' \
      --replace-fail 'set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY' '# set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY' \
      --replace-fail 'set(CMAKE_LIBRARY_OUTPUT_DIRECTORY' '# set(CMAKE_LIBRARY_OUTPUT_DIRECTORY'

    # nix also wants to use cmake's usual install machinerery to fixup RPATHs etc correctly.
    # use that.
    echo 'install(TARGETS makemsix DESTINATION bin)' >> src/makemsix/CMakeLists.txt
    echo -e '\ninstall(TARGETS ''${PROJECT_NAME} DESTINATION lib)' >> src/msix/CMakeLists.txt
  '';

  buildInputs = [
    icu
    openssl
    zlib
  ];

  preBuild = ''
    # nix uses a different build directory than src directory for cmake builds,
    # which is different than how ms was doing it.
    # copy over files generated during configure time to the build dir rather
    # than fix the cmake files, this seems easier.
    cp lib/xerces/src/xercesc/util/{Xerces_autoconf_config.hpp,XercesVersion.hpp} \
      /build/source/lib/xerces/src/xercesc/util/
  '';

  # taken from makelinux.sh
  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=MinSizeRel"
    "-DSKIP_BUNDLES=off"
    "-DUSE_VALIDATION_PARSER=off"
    "-DCMAKE_TOOLCHAIN_FILE=../cmake/linux.cmake"
    "-DMSIX_PACK=off"
    "-DMSIX_SAMPLES=on"
    "-DMSIX_TESTS=on"
    "-DLINUX=on"
    # extra options on top of makelinux.sh
    "-DUSE_SHARED_ZLIB=on"
  ];

  meta = {
    description = "The MSIX SDK project is an effort to enable developers on a variety of platforms to pack and unpack packages for the purposes of distribution from either the Microsoft Store, or their own content distribution networks.";
    homepage = "https://github.com/microsoft/msix-packaging";
    mainProgram = "makemsix";
    license = lib.licenses.mit;
    teams = [ lib.maintainers.euank ];
    platforms = lib.platforms.unix;
  };
})
