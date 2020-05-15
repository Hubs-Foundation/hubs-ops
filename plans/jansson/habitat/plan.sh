pkg_name=jansson
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="2.12"
pkg_license=('MIT')
pkg_source="http://www.digip.org/jansson/releases/${pkg_name}-${pkg_version}.tar.gz"
pkg_filename="${pkg_name}-${pkg_version}.tar.gz"
pkg_shasum="5f8dec765048efac5d919aded51b26a32a05397ea207aa769ff6b53c7027d2c9"
pkg_build_deps=(core/make core/gcc)
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
pkg_description="Jansson is a C library for encoding, decoding and manipulating JSON data."
pkg_upstream_url="http://www.digip.org/jansson/"

do_build() {
  CFLAGS="${CFLAGS} -O2 -g" CPPFLAGS="${CPPFLAGS} -O2 -g" CXXFLAGS="${CXXFLAGS} -O2 -g" ./configure --prefix "${pkg_prefix}"
  make
}
