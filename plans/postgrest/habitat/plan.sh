pkg_name=postgrest
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_upstream_url=https://github.com/begriffs/postgrest
pkg_source=https://github.com/begriffs/postgrest.git
pkg_version=0.5.0
pkg_branch=v0.5.0.0
ghc_version=8.4.3
pkg_bin_dirs=(bin)

pkg_build_deps=(
  mozillareality/haskell-stack/1.6.5
  core/git
  core/patchelf
  core/gcc
)
pkg_deps=(
  core/gcc-libs
  core/glibc
  core/openssl
  core/zlib
  mozillareality/ncurses5-compat-libs
)

do_begin() {
  export GIT_DIR="${HAB_CACHE_SRC_PATH}/${pkg_name}.git"
}

do_download() {
  if [ -d "${GIT_DIR}" ]; then
    git fetch --all
  else
    git clone --bare "${pkg_source}" "${GIT_DIR}"
  fi

  pkg_commit="$(git rev-parse --short ${pkg_branch})"
  pkg_last_tag="$(git describe --tags --abbrev=0 ${pkg_commit})"
  pkg_last_version=${pkg_last_tag#v}
  pkg_version="${pkg_last_version}+$(git rev-list ${pkg_last_tag}..${pkg_commit} --count).${pkg_commit}"
  pkg_dirname="${pkg_name}-${pkg_version}"
  pkg_prefix="$HAB_PKG_PATH/${pkg_origin}/${pkg_name}/${pkg_version}/${pkg_release}"
  pkg_artifact="$HAB_CACHE_ARTIFACT_PATH/${pkg_origin}-${pkg_name}-${pkg_version}-${pkg_release}-${pkg_target}.${_artifact_ext}"

  return 0
}

do_verify() {
  return 0
}

do_unpack() {
  mkdir "${HAB_CACHE_SRC_PATH}/${pkg_dirname}" || echo ""

  pushd "${HAB_CACHE_SRC_PATH}/${pkg_dirname}" > /dev/null
  echo "checking out into $(pwd)"
  git --work-tree=. checkout --force "${pkg_commit}"
  git --work-tree=. submodule update --init --recursive
  popd > /dev/null

  return $?
}

do_build() {
  mkdir "${HAB_CACHE_SRC_PATH}/${pkg_dirname}/bin" || echo ""
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${LD_RUN_PATH}"
  export LIBRARY_PATH="$LIBRARY_PATH:${LD_RUN_PATH}"
  export PATH="$PATH:/root/.local/bin"
  pushd "${HAB_CACHE_SRC_PATH}/${pkg_dirname}" > /dev/null

  # Hacks needed for dynamic linking failures during GHC build
  rm /lib64/ld-linux-x86-64.so.2 || echo ""
  ln -s $(pkg_path_for core/glibc)/lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

  # Custom stack.yaml after adding extra deps :P
  cat > "stack.yaml" <<- EOM
resolver: lts-9.6
extra-deps:
  - adjunctions-4.4
  - aeson-1.4.2.0
  - ansi-terminal-0.9
  - ansi-wl-pprint-0.6.8.2
  - appar-0.1.7
  - asn1-encoding-0.9.5
  - asn1-parse-0.9.4
  - asn1-types-0.3.2
  - async-2.1.1.1
  - attoparsec-0.13.2.2
  - auto-update-0.1.4
  - base-4.7.0.2
  - base64-bytestring-1.0.0.2
  - base-compat-0.10.5
  - base-compat-batteries-0.10.5
  - basement-0.0.8
  - base-orphans-0.8
  - base-prelude-1.3
  - base-unicode-symbols-0.2.3
  - bifunctors-5.5.3
  - binary-parser-0.5.5
  - bsb-http-chunked-0.0.0.4
  - byteorder-1.0.4
  - bytestring-0.10.2.0
  - bytestring-builder-0.10.8.2.0
  - bytestring-strict-builder-0.4.5.1
  - bytestring-tree-builder-0.2.7.2
  - cabal-doctest-1.0.6
  - call-stack-0.1.0
  - case-insensitive-1.2.0.11
  - cassava-0.5.1.0
  - cereal-0.5.8.0
  - charset-0.3.7.1
  - colour-2.3.4
  - comonad-5.0.4
  - concise-0.1.0.1
  - configurator-ng-0.0.0.1
  - contravariant-1.5
  - contravariant-extras-0.3.4
  - cookie-0.4.4
  - critbit-0.2.0.0
  - cryptohash-md5-0.11.100.1
  - cryptohash-sha1-0.11.100.1
  - cryptonite-0.25
  - data-bword-0.1.0.1
  - data-checked-0.3
  - data-default-class-0.1.2.0
  - data-dword-0.3.1.2
  - data-endian-0.1.1
  - data-ordlist-0.4.7.0
  - data-serializer-0.3.4
  - data-textual-0.3.0.2
  - deepseq-1.3.0.2
  - distributive-0.6
  - dlist-0.8.0.5
  - easy-file-0.2.2
  - either-4.5
  - entropy-0.4.1.4
  - erf-2.0.0.0
  - exceptions-0.8.3
  - expiring-cache-map-0.0.6.1
  - fail-4.9.0.0
  - fast-logger-2.4.13
  - free-4.12.4
  - generics-sop-0.4.0.1
  - gitrev-1.3.1
  - hashable-1.2.7.0
  - hashtables-1.2.3.1
  - haskell-src-exts-1.20.3
  - haskell-src-meta-0.8.0.3
  - hasql-1.1
  - hasql-pool-0.4.3
  - hasql-transaction-0.5.2
  - heredoc-0.2.0.0
  - hjsonpointer-1.1.1
  - hjsonschema-1.5.0.1
  - hourglass-0.2.12
  - http2-1.6.4
  - HTTP-4000.3.12
  - http-date-0.0.8
  - http-media-0.7.1.3
  - http-types-0.12.2
  - HUnit-1.6.0.0
  - insert-ordered-containers-0.2.1.0
  - integer-logarithms-1.0.2.2
  - interpolatedstring-perl6-1.0.1
  - invariant-0.5.1
  - iproute-1.7.7
  - jose-0.7.0.0
  - kan-extensions-5.2
  - lens-4.17
  - lens-aeson-1.0.2
  - loch-th-0.2.2
  - memory-0.14.18
  - mime-types-0.1.0.9
  - mmorph-1.1.2
  - monad-control-1.0.2.3
  - MonadRandom-0.5.1.1
  - monad-time-0.3.1.0
  - mtl-2.2.2
  - mtl-compat-0.2.1.3
  - network-2.8.0.0
  - network-byte-order-0.0.0.0
  - network-info-0.2.0.10
  - network-ip-0.3.0.2
  - network-uri-2.6.1.0
  - old-locale-1.0.0.7
  - old-time-1.1.0.3
  - Only-0.1
  - optparse-applicative-0.14.3.0
  - parallel-3.2.2.0
  - parsec-3.1.13.0
  - parsers-0.12.9
  - pem-0.2.4
  - placeholders-0.1
  - postgresql-binary-0.12.1.2
  - postgresql-libpq-0.9.4.2
  - prelude-extras-0.4.0.3
  - primitive-0.6.4.0
  - profunctors-5.3
  - protolude-0.2
  - psqueues-0.2.7.1
  - QuickCheck-2.12.6.1
  - quickcheck-instances-0.3.19
  - random-1.1
  - Ranged-sets-0.3.0
  - reflection-2.1.4
  - regex-base-0.93.2
  - regex-tdfa-1.2.3.1
  - resource-pool-0.2.3.2
  - resourcet-1.2.2
  - retry-0.7.7.0
  - safe-0.3.15
  - scientific-0.3.6.2
  - semigroupoids-5.3.2
  - semigroups-0.18.5
  - simple-sendfile-0.2.28
  - sop-core-0.4.0.0
  - split-0.2.3.3
  - StateVar-1.1.1.1
  - stm-2.4.5.1
  - streaming-commons-0.2.1.0
  - swagger2-2.3.1
  - syb-0.7
  - tagged-0.8.6
  - text-1.2.3.1
  - text-latin1-0.3.1
  - text-printer-0.5
  - tf-random-0.5
  - th-abstraction-0.2.10.0
  - th-expand-syns-0.4.4.0
  - th-lift-0.7.11
  - th-lift-instances-0.1.11
  - th-orphans-0.13.6
  - th-reify-many-0.1.8
  - time-1.4.2
  - time-locale-compat-0.1.1.5
  - transformers-base-0.4.5.2
  - transformers-compat-0.6.2
  - tuple-th-0.2.5
  - type-hint-0.1
  - unix-compat-0.5.1
  - unix-time-0.4.5
  - unliftio-core-0.1.2.0
  - unordered-containers-0.2.10.0
  - utf8-string-1.0.1.1
  - uuid-1.3.13
  - uuid-types-1.0.3
  - vault-0.3.1.2
  - vector-0.12.0.2
  - void-0.7.2
  - wai-3.2.2
  - wai-cors-0.2.6
  - wai-extra-3.0.25
  - wai-logger-2.3.4
  - wai-middleware-static-0.8.2
  - warp-3.2.26
  - word8-0.1.3
  - x509-1.7.5
  - zlib-0.6.2
ghc-options:
  postgrest: -O2 -Werror -Wall -fwarn-identities -fno-warn-redundant-constraints
nix:
  packages: [postgresql, zlib]
allow-newer: true
EOM

  stack build \
    --extra-include-dirs="$(pkg_path_for core/zlib)/include" \
    --copy-bins \
    --local-bin-path="${HAB_CACHE_SRC_PATH}/${pkg_dirname}/bin" \
    --resolver ghc-8.0.1 \
    && return 0

  return 1
}

do_install() {
  cp -vr ./bin "${pkg_prefix}"

  return 0
}
