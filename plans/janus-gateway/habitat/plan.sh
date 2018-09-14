pkg_name=janus-gateway
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="0.4.3"
pkg_license=('GPLv3')
pkg_description="Janus is an open source, general purpose, WebRTC gateway"
pkg_upstream_url="https://janus.conf.meetecho.com/"
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)
pkg_build_deps=(
  core/automake
  core/autoconf
  core/make
  core/gcc
  core/pkg-config
  core/which
  core/libtool
  core/m4
  core/rust
  core/cacerts
  core/git
  mozillareality/gnutls
  mozillareality/gengetopt
)

pkg_deps=(
  core/openssl
  core/glib
  core/util-linux
  core/sqlite
  core/p11-kit
  core/gcc # reqd for libasan
  mozillareality/jansson
  mozillareality/libsrtp
  mozillareality/usrsctp
  mozillareality/libmicrohttpd
  mozillareality/libwebsockets
  mozillareality/opus
  mozillareality/libnice

  # https://github.com/habitat-sh/habitat/issues/3303
  core/zlib
  core/glibc
  core/gcc-libs
  core/nettle
  core/pcre
  core/libtasn1
)

git-get () {
    repo=$1
    version=$2

    rm -rf $repo
    git clone https://github.com/$repo $repo

    pushd $repo
    git fetch
    git checkout $version
    git reset --hard $version
    git clean -ffdx
    popd
}

do_download() {
  export GIT_SSL_CAINFO="$(pkg_path_for core/cacerts)/ssl/certs/cacert.pem"

  pushd $HAB_CACHE_SRC_PATH

  git-get meetecho/janus-gateway 3c5ad1b125f696a32c85420f31a24eec79b35028
  git-get mozilla/janus-plugin-sfu 300561965e0eed162831a07ffa7ea8b94f4a2f1b

  popd
}

do_strip() {
    build_line "Conspicuously not stripping unneeded symbols from binaries and libraries, like Habitat would do by default"
}

do_build() {
  pushd $HAB_CACHE_SRC_PATH/meetecho/janus-gateway

  libtoolize


  # This is a hack, setting ACLOCAL flags etc didn't seem to work
  cp "$(pkg_path_for core/pkg-config)/share/aclocal/pkg.m4" "$(pkg_path_for core/automake)/share/aclocal/"

  ./autogen.sh

  CFLAGS="${CFLAGS} -fsanitize=address -fno-omit-frame-pointer" LDFLAGS="${LDFLAGS} -lasan" ./configure --prefix="$pkg_prefix" --disable-all-plugins --disable-all-handlers

  make

  popd
  pushd $HAB_CACHE_SRC_PATH/mozilla/janus-plugin-sfu

  # Need to pass the library paths directly into rustc
  RUSTFLAGS="-C link-arg=-Wl,-L,${LD_RUN_PATH//:/ -C link-arg=-Wl,-L,}" cargo build --release
  popd
}

do_install() {
  pushd $HAB_CACHE_SRC_PATH/meetecho/janus-gateway

  do_default_install

  mkdir -p "${pkg_prefix}/lib/janus/plugins"
  mkdir -p "${pkg_prefix}/lib/janus/events"
  cp $HAB_CACHE_SRC_PATH/mozilla/janus-plugin-sfu/target/release/libjanus_plugin_sfu.so "${pkg_prefix}/lib/janus/plugins"

  popd
}
