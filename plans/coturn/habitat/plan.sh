pkg_name=coturn
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="4.5.1.1"
pkg_source="https://github.com/gfodor/coturn/archive/${pkg_version}.tar.gz"
pkg_shasum="a7d1b2f68d744a4778ce5fb266eaa71844a79442d8390d285539592ed1d54000"
pkg_license=('COTURN')
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
