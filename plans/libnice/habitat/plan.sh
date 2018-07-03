pkg_name=libnice
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

# Need to package HEAD of master for now because of
# https://github.com/meetecho/janus-gateway/issues/788
#
# 0.1.15 isn't released yet

pkg_version="0.1.15"
pkg_license=('MPL')
pkg_shasum="61112d9f3be933a827c8365f20551563953af6718057928f51f487bfe88419e1"
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)

pkg_build_deps=(
  core/file
  core/diffutils
  core/make
  core/gcc
  core/pkg-config
  core/cacerts
  core/automake
  core/autoconf
  core/make
  core/gcc
  core/pkg-config
  core/libtool
  core/m4
  core/git
  core/p11-kit
)
pkg_deps=(
  core/glib
  core/glibc # https://github.com/habitat-sh/habitat/issues/3303
  mozillareality/gnutls
  mozillareality/nettle
  mozillareality/libtasn1
  mozillareality/pcre
)

pkg_description="Libnice is an implementation of the IETF's Interactive Connectivity Establishment (ICE) standard (RFC 5245)"
pkg_upstream_url="https://nice.freedesktop.org/wiki/"

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

  git-get libnice/libnice

  popd
}

do_build() {
  pushd $HAB_CACHE_SRC_PATH/libnice/libnice

  libtoolize

  # This is a hack, setting ACLOCAL flags etc didn't seem to work
  cp "$(pkg_path_for core/pkg-config)/share/aclocal/pkg.m4" "$(pkg_path_for core/automake)/share/aclocal/"

  # Skip docs + tests for now
  sed -i 's/^.*gtkdoc.*$//g' autogen.sh
  sed -i '/docs/d' configure.ac
  sed -i '/[^/]tests/d' configure.ac
  sed -i '/tests/d' Makefile.am
  sed -i '/docs/d' Makefile.am

  rm -rf docs
  rm -rf tests

  sh autogen.sh --prefix=${pkg_prefix}

  # This is a hack -- there is a name conflict between socket.h in gnutls and
  # socket.h in the libnice/socket directory, and the included
  # Makefile.am/Makefile ends up preferring the former instead of the latter
  # due to the order of the various include overrides.
  INCLUDES="-I$(pwd)/socket" make -e

  popd
}

do_install() {
  pushd $HAB_CACHE_SRC_PATH/libnice/libnice

  do_default_install

  popd
}
