pkg_origin=mozillareality
pkg_name=libevent
pkg_version=2.1.11
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_license=('BSD-3-Clause')
pkg_source=https://github.com/${pkg_name}/${pkg_name}/releases/download/release-${pkg_version}-stable/${pkg_name}-${pkg_version}-stable.tar.gz
pkg_upstream_url=https://libevent.org
pkg_description="The libevent API provides a mechanism to execute a callback function when a specific event occurs \
  on a file descriptor or after a timeout has been reached. Furthermore, libevent also support callbacks due to \
  signals or regular timeouts."
pkg_shasum=a65bac6202ea8c5609fd5c7e480e6d25de467ea1917c08290c521752f147283d
pkg_dirname=${pkg_name}-${pkg_version}-stable
pkg_deps=(core/glibc)
pkg_build_deps=(core/cacerts core/gcc core/make mozillareality/openssl mozillareality/zlib)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)

do_build() {
  CFLAGS="${CFLAGS} -O2 -g" CPPFLAGS="${CPPFLAGS} -O2 -g" CXXFLAGS="${CXXFLAGS} -O2 -g" ./configure --prefix=${pkg_prefix}
  make
}
