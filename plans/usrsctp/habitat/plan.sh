pkg_name=usrsctp
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="0.9.7.0"
pkg_source="https://github.com/gfodor/usrsctp/archive/${pkg_version}.tar.gz"
pkg_shasum="5946062e5dee8893d2a0c4f9cc23a32d679736faf1bb45bf3e29730760b158f4"
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
  CFLAGS="${CFLAGS} -O2 -g" CPPFLAGS="${CPPFLAGS} -O2 -g" CXXFLAGS="${CXXFLAGS} -O2 -g" ./configure --prefix=${pkg_prefix}
  make
}
