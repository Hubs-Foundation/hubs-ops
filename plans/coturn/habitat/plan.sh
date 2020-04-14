pkg_name=coturn
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="4.5.1.1"
pkg_source="https://github.com/coturn/coturn/archive/${pkg_version}.tar.gz"
pkg_shasum="8eabe4c241ad9a74655d8516c69b1fa3275e020e7f7fca50a6cb822809e7c220"
pkg_license=('COTURN')
pkg_deps=(
  mozillareality/openssl
  mozillareality/libevent
  mozillareality/zlib
  mozillareality/pcre
  core/postgresql-client
)

pkg_build_deps=(
  core/make
  core/gcc
  core/which
  core/libtool
  core/m4
  core/automake
  core/autoconf
)

pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
pkg_bin_dirs=(bin)
pkg_pconfig_dirs=$pkg_prefix
pkg_description="Coturn is a VoIP media traffic NAT traversal server and gateway. It can be used as a general-purpose network traffic TURN server and gateway, too."
pkg_upstream_url="https://github.com/coturn/coturn"

do_build() {
  CFLAGS="${CFLAGS} -O2 -g" ./configure --prefix=${pkg_prefix}
  make
}
