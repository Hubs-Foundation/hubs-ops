set -e

# BLDR_RET_PUB_B64='U0lHLVBVQi0xC
# BLDR_HAB_PVT_B64='U0lHLVNFQy0xC
# BLDR_HAB_TOKEN='_Qk9YLTEKYmxkci
# BLDR_RET_TOKEN='_Qk9YLTEKYmxkci

apk add git curl py3-pip

## preps
org="biome-sh";repo="biome"
ver=$(curl -s https://api.github.com/repos/$org/$repo/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
dl="https://github.com/$org/$repo/releases/download/$ver/bio-${ver#"v"}-x86_64-linux.tar.gz"
echo "[info] getting bio from: $dl" && curl -L -o bio.gz $dl && tar -xf bio.gz
cp ./bio /usr/bin/bio && bio --version

export HAB_ORIGIN=mozillareality

mkdir -p /hab/cache/keys/
mkdir -p ./hab/cache/keys/
echo $BLDR_RET_PUB_B64 | base64 -d > /hab/cache/keys/mozillareality-20190117233449.pub
echo $BLDR_RET_PUB_B64 | base64 -d > ./hab/cache/keys/mozillareality-20190117233449.pub
echo $BLDR_HAB_PVT_B64 | base64 -d > /hab/cache/keys/mozillareality-20190117233449.sig.key
echo $BLDR_HAB_PVT_B64 | base64 -d > /hab/cache/keys/mozillareality-20190117233449.sig.key


echo "### build hab pkg"
export HAB_AUTH_TOKEN=$BLDR_HAB_TOKEN


mkdir /repo/ytdl-api-deps && cd /repo/ytdl-api-deps
git clone https://github.com/ytdl-org/youtube-dl.git
mv ./youtube-dl/youtube_dl/ ./youtube_dl/
pip install flask -t ./repo/ytdl-api-deps/

cd /repo
ls -lha
bio pkg build -k mozillareality .
# exit 1

### upload
echo "### upload hab pkg"
export HAB_BLDR_URL="https://bldr.reticulum.io"
export HAB_AUTH_TOKEN=$BLDR_RET_TOKEN
export HAB_ORIGIN_KEYS=mozillareality_ret
echo $BLDR_RET_PUB_B64 | base64 -d > /hab/cache/keys/mozillareality-20190117233449.pub
hart="/hab/cache/artifacts/$HAB_ORIGIN-youtube-dl-api-server*.hart"
ls -lha $hart
bio pkg upload $hart