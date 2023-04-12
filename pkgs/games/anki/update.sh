#! /usr/bin/env nix-shell
#! nix-shell -i bash -p common-updater-scripts curl jq nix-prefetch-github prefetch-yarn-deps nixpkgs-fmt

set -x -eu -o pipefail

cd "$(dirname ${BASH_SOURCE[0]})"

tag="$(curl -f -sSL https://api.github.com/repos/ankitects/anki/releases/latest | jq -r '.tag_name')"
cur_release="$(nix eval -f ./release.nix --json | jq -r '.version')"

if [[ "$cur_release" == "$tag" ]]; then
    echo "Up to date"
    exit 0
fi

echo "Updating from $cur_release to $tag"

WORKDIR="$(mktemp -d)"
trap "rm -rf ${WORKDIR}" EXIT

commit=$(curl --silent -f ${GITHUB_TOKEN:+-u ":$GITHUB_TOKEN"} \
    https://api.github.com/repos/ankitects/anki/tags \
    | jq -r "map(select(.name == \"${tag}\")) | .[0] | .commit.sha")

repoHash="$(nix-prefetch-github ankitects anki --rev "$commit" --fetch-submodules --json | jq -r '.sha256')"

curl -sSL -f https://raw.githubusercontent.com/ankitects/anki/${commit}/Cargo.lock > Cargo.lock
curl -sSL -f https://raw.githubusercontent.com/ankitects/anki/${commit}/yarn.lock > "$WORKDIR/yarn.lock"

yarnOldHash="$(prefetch-yarn-deps "$WORKDIR/yarn.lock")"
yarnHash="$(nix hash to-sri --type sha256 $yarnOldHash)"

cat > release.nix <<EONIX
{
  version = "$tag";
  commit = "$commit";
  hash = "sha256-$repoHash";
  yarnHash = "$yarnHash";
}
EONIX

nixpkgs-fmt release.nix

echo "Updated! Please verify it actually builds and functions as this script only updates hashes without even validating it will build"
