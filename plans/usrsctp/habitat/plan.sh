pkg_name=usrsctp
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="0.9.6.0"
pkg_source="https://github.com/gfodor/usrsctp/archive/${pkg_version}.tar.gz"
pkg_shasum="a7d1b2f68d744a4778ce5fb266eaa71844a79442d8390d285539592ed1d54000"
pkg_license=('BSD-3')
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
pkg_description="A portable SCTP userland stack"
pkg_upstream_url="https://github.com/sctplab/usrsctp"

do_build() {
  ./bootstrap
  ./configure --prefix=${pkg_prefix}
  make
}
