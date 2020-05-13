pkg_name=janus-gateway
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="0.9.2"
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
    mozillareality/gnutls/3.6.9
    mozillareality/gengetopt/2.23
)

# versions are pinned for convenience building with Habitat, not because we give a crap about
# having these versions in particular -- latest versions of everything should be sufficient
pkg_deps=(
    mozillareality/gcc
    mozillareality/glib
    core/openssl/1.0.2r/20190305210149 
    core/p11-kit/0.23.10/20190117183627
    core/sqlite/3130000/20190115154252
    mozillareality/util-linux/2.34

    mozillareality/jansson/2.12
    mozillareality/libmicrohttpd/0.9.66
    mozillareality/libnice/0.1.16
    mozillareality/libsrtp/2.2.0
    mozillareality/libwebsockets/2.4.2
    mozillareality/opus/1.3.1
    mozillareality/usrsctp/0.9.7.0
    mozillareality/libconfig/1.7.2

    # https://github.com/habitat-sh/habitat/issues/3303
    mozillareality/zlib/1.2.11
    core/glibc/2.27/20190115002733
    mozillareality/gcc-libs/9.1.0
    mozillareality/nettle/3.5.1
    mozillareality/pcre/8.42
    mozillareality/libtasn1/4.13
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

  git-get meetecho/janus-gateway v0.9.2
  pushd meetecho/janus-gateway
  popd

  git-get mozilla/janus-plugin-sfu 3694c36040eea4de1e80b83447a3625156454956

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

  CFLAGS="${CFLAGS} -O2 -g -fno-omit-frame-pointer" ./configure --prefix="$pkg_prefix" --disable-all-plugins --disable-all-handlers

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
