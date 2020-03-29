with import <nixpkgs> {};

{ stdenv, lib, git, go, buildGoModule}:

with lib;

buildGoModule rec {
  name = "k3s";
  version = "1.17.3+k3s1";

  modSha256 = "0wkp7rrdk2hg28g2pr0hdpqhlijy4myp8x6nyrwk4qn69fi8i475";

  src = fetchgit {
    url = "https://github.com/rancher/k3s";
    rev = "v${version}";
    leaveDotGit = true; # for version / build date below
    sha256 = "0qahyc0mf9glxj49va6d20mcncqg4svfic2iz8b1lqid5c4g68mm";
  };

  buildInputs = [ git ];

  # Additional -X flags for overriding some stuff, like datadir

  buildPhase = ''
    echo "Build phase"

    # Mimicing ./scripts/build in the k3s repo
    buildDate="$(date -d "$(git log -1 --format=%ai)" -u "+%Y-%m-%dT%H:%M:%SZ")"
    VERSION="v${version}"
    VERSIONFLAGS="
        -X ''${PKG}/pkg/version.Version=''${VERSION}
        -X ''${PKG}/pkg/version.GitCommit=''${VERSION}

        -X ''${VENDOR_PREFIX}k8s.io/client-go/pkg/version.gitVersion=''${VERSION}
        -X ''${VENDOR_PREFIX}k8s.io/client-go/pkg/version.gitCommit=''${VERSION}
        -X ''${VENDOR_PREFIX}k8s.io/client-go/pkg/version.gitTreeState=""
        -X ''${VENDOR_PREFIX}k8s.io/client-go/pkg/version.buildDate=''${buildDate}

        -X ''${VENDOR_PREFIX}k8s.io/component-base/version.gitVersion=''${VERSION}
        -X ''${VENDOR_PREFIX}k8s.io/component-base/version.gitCommit=''${VERSION}
        -X ''${VENDOR_PREFIX}k8s.io/component-base/version.gitTreeState=""
        -X ''${VENDOR_PREFIX}k8s.io/component-base/version.buildDate=''${buildDate}

        -X ''${VENDOR_PREFIX}''${PKG_CONTAINERD}/version.Version=''${VERSION_CONTAINERD}
        -X ''${VENDOR_PREFIX}''${PKG_CONTAINERD}/version.Package=''${PKG_RANCHER_CONTAINERD}
        -X ''${VENDOR_PREFIX}''${PKG_CRICTL}/pkg/version.Version=''${VERSION_CRICTL}
    "
    TAGS="ctrd osusergo providerless"

    go build -tags "$TAGS" -ldflags "$VERSIONFLAGS -w -s" -o $GOPATH/bin/containerd ./cmd/server/main.go

    # TODO: allow configuring which of these are taken from the system vs the k3s repo
    for bin in k3s-agent k3s-server kubectl crictl ctr; do
      ln -s containerd $GOPATH/bin/$bin
    done
  '';

  installPhase = ''
    mkdir -p "$out"
    cp -r "$GOPATH/bin" "$out"
  '';

  meta = {
    description = "k3s";
    license = licenses.asl20;
    homepage = https://k3s.io;
    maintainers = [];
    platforms = platforms.linux;
  };
}
