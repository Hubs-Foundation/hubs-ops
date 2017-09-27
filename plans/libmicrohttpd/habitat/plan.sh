pkg_name=libmicrohttpd
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="0.9.55"
pkg_source="http://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-0.9.55.tar.gz"
pkg_shasum="0c1cab8dc9f2588bd3076a28f77a7f8de9560cbf2d80e53f9a8696ada80ed0f8"
pkg_build_deps=(core/make core/gcc) 
pkg_license=('LGPL-2.1')
pkg_description="GNU libmicrohttpd is a small C library that is supposed to make it easy to run an HTTP server as part of another application."
pkg_upstream_url="https://www.gnu.org/software/libmicrohttpd/"
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
