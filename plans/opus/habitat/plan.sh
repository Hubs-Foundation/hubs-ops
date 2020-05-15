pkg_name=opus
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="1.3.1"
pkg_license=('BSD')
pkg_source="https://archive.mozilla.org/pub/opus/opus-${pkg_version}.tar.gz"
pkg_filename="${pkg_name}-${pkg_version}.tar.gz"
pkg_shasum="65b58e1e25b2a114157014736a3d9dfeaad8d41be1c8179866f144a2fb44ff9d"
pkg_build_deps=(core/make core/gcc)
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
pkg_description="Opus is a totally open, royalty-free, highly versatile audio codec."
pkg_upstream_url="http://opus-codec.org/"

do_build() {
  CFLAGS="${CFLAGS} -O2 -g" CPPFLAGS="${CPPFLAGS} -O2 -g" CXXFLAGS="${CXXFLAGS} -O2 -g" ./configure --prefix "${pkg_prefix}"
  make
}
