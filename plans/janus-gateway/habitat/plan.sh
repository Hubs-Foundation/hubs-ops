pkg_name=janus-gateway
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="0.4.5"
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

# versions are pinned for convenience building with Habitat, not because we give a crap about
# having these versions in particular -- latest versions of everything should be sufficient
pkg_deps=(
    core/gcc/7.3.0/20180608051919 # reqd for libasan
    core/glib/2.50.3/20180718153537
    core/openssl/1.0.2n/20180608102213
    core/p11-kit/0.23.10/20180608191918
    core/sqlite/3130000/20180608141313
    core/util-linux/2.31.1/20180608101132

    mozillareality/jansson/2.10/20170922013102
    mozillareality/libmicrohttpd/0.9.55/20170923183119
    mozillareality/libnice/0.1.15/20180914001451
    mozillareality/libsrtp/2.1.0/20170923183826
    mozillareality/libwebsockets/2.4.2/20180702225550
    mozillareality/opus/1.2.1/20170922184322
    mozillareality/usrsctp/0.9.4.0/20170923224507

    # https://github.com/habitat-sh/habitat/issues/3303
    core/zlib/1.2.11/20180608050617
    core/glibc/2.27/20180608041157
    core/gcc-libs/7.3.0/20180608091701
    core/nettle/3.4/20180609173754
    core/pcre/8.41/20180608092740
    core/libtasn1/4.13/20180608191858
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

  git-get meetecho/janus-gateway v0.4.5
  git-get mozilla/janus-plugin-sfu 97be0ad45747d5c04f2e10a5b3e74cc997445d89

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
