pkg_name=janus-gateway
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="0.2.4"
pkg_license=('GPLv3')
pkg_source="https://github.com/meetecho/janus-gateway/archive/v${pkg_version}.tar.gz"
pkg_shasum="b1064036dcdaae804e9e76e58fa7ec639cfdf09c716ece32b5a0a459b48c2ba7"
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
  mozillareality/jansson
  mozillareality/libsrtp
  mozillareality/usrsctp
  mozillareality/libmicrohttpd
  mozillareality/libwebsockets
  mozillareality/opus
  mozillareality/libnice
  mozillareality/p11-kit

  # https://github.com/habitat-sh/habitat/issues/3303
  core/zlib
  core/glibc
  core/gcc-libs
  mozillareality/libtasn1
  mozillareality/pcre
  mozillareality/nettle
)

do_download() {
  export GIT_SSL_CAINFO="$(pkg_path_for core/cacerts)/ssl/certs/cacert.pem"
  pushd /hab/cache/src
  rm -rf janus-retproxy
  git clone https://github.com/mquander/janus-retproxy
  pushd janus-retproxy
  git checkout master
  popd
  popd

  do_default_download
}

do_build() {
  libtoolize
  
  # Another hack, need to include LD_LIBRARY_PATH due to configure
  # causing capability checks to fail due to dynamic linker
  # https://github.com/habitat-sh/habitat/issues/3303
  export LD_LIBRARY_PATH=$LD_RUN_PATH

  # This is a hack, setting ACLOCAL flags etc didn't seem to work
  cp "$(pkg_path_for core/pkg-config)/share/aclocal/pkg.m4" "$(pkg_path_for core/automake)/share/aclocal/"

  pushd ../janus-retproxy

  # Need to pass the library paths directly into rustc
  RUSTFLAGS="-C link-arg=-Wl,-L,${LD_LIBRARY_PATH//:/ -C link-arg=-Wl,-L,}" cargo build
  popd

  sh autogen.sh

  sh configure --prefix="$pkg_prefix"

  make
}

do_install() {
  do_default_install

  cp ../janus-retproxy/target/debug/libjanus_retproxy.so "${pkg_prefix}/lib/janus/plugins"
  mkdir -p "${pkg_prefix}/lib/janus/events"
}
