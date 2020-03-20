pkg_name=libmicrohttpd
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="0.9.66"
pkg_source="http://ftp.gnu.org/gnu/${pkg_name}/${pkg_name}-${pkg_version}.tar.gz"
pkg_shasum="4e66d4db1574f4912fbd2690d10d227cc9cc56df6a10aa8f4fc2da75cea7ab1b"
pkg_build_deps=(core/make core/gcc) 
pkg_license=('LGPL-2.1')
pkg_description="GNU libmicrohttpd is a small C library that is supposed to make it easy to run an HTTP server as part of another application."
pkg_upstream_url="https://www.gnu.org/software/libmicrohttpd/"
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
