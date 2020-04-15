{ lib, fetchFromGitHub, buildGoPackage, btrfs-progs, go-md2man, utillinux, writeShellScriptBin }:

with lib;

let 
  # This is a hack so that `containerd --version` has pretty output (with the
  # version number and git revision).
  # We have roughly three options:
  #   1. Patch the makefile to have env vars override it
  #   2. leaveDotGit in our fetchgit call (which is buggy, see #8567)
  #   3. Fake out git output so it works without patching
  # This script is for option 3.
  # It implements only the options the containerd makefile needs to build it with correct output.
  mockGit = writeShellScriptBin "git" ''
    case $1 in
      describe)
        echo "$VERSION"
        ;;
      rev-parse)
        echo "$GIT_COMMIT"
        ;;
      diff)
        exit 0
        ;;
      *)
        echo "Unknown git command for mockGit hack: $@"
        exit 1
        ;;
    esac
  '';
in
buildGoPackage rec {
  pname = "containerd";
  version = "1.2.13";
  # git commit for the above version's tag
  commit = "7ad184331fa3e55e52b890ea95e65ba581ae3429";

  src = fetchFromGitHub {
    owner = "containerd";
    repo = "containerd";
    rev = "v${version}";
    sha256 = "1rac3iak3jpz57yarxc72bxgxvravwrl0j6s6w2nxrmh2m3kxqzn";
  };

  goPackagePath = "github.com/containerd/containerd";
  outputs = [ "bin" "out" "man" ];

  nativeBuildInputs = [ go-md2man utillinux mockGit ];

  buildInputs = [ btrfs-progs ];

  buildFlags = [ "VERSION=v${version}" "GIT_COMMIT=${commit}" ];

  BUILDTAGS = []
    ++ optional (btrfs-progs == null) "no_btrfs";

  buildPhase = ''
    cd go/src/${goPackagePath}
    patchShebangs .
    make binaries
  '';

  installPhase = ''
    for b in bin/*; do
      install -Dm555 $b $bin/$b
    done

    make man
    manRoot="$man/share/man"
    mkdir -p "$manRoot"
    for manFile in man/*; do
      manName="$(basename "$manFile")" # "docker-build.1"
      number="$(echo $manName | rev | cut -d'.' -f1 | rev)"
      mkdir -p "$manRoot/man$number"
      gzip -c "$manFile" > "$manRoot/man$number/$manName.gz"
    done
  '';

  meta = {
    homepage = "https://containerd.io/";
    description = "A daemon to control runC";
    license = licenses.asl20;
    maintainers = with maintainers; [ offline vdemeester ];
    platforms = platforms.linux;
  };
}
