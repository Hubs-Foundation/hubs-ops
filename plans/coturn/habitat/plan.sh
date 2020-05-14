pkg_name=coturn
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="4.5.3.0"
pkg_source="https://github.com/mozillareality/coturn/archive/${pkg_version}.tar.gz"
pkg_shasum="760e5ad2057ac306b9582c401efa28cc0ad46423f1cd4d4acd7fa4074016039e"
pkg_license=('COTURN')
pkg_deps=(
  mozillareality/openssl
  mozillareality/libevent
  mozillareality/zlib
  mozillareality/pcre
  mozillareality/postgresql-client
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
