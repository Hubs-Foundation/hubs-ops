pkg_name=jansson
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="2.10"
pkg_license=('MIT')
pkg_source="http://www.digip.org/jansson/releases/${pkg_name}-${pkg_version}.tar.gz"
pkg_filename="${pkg_name}-${pkg_version}.tar.gz"
pkg_shasum="78215ad1e277b42681404c1d66870097a50eb084be9d771b1d15576575cf6447"
pkg_build_deps=(core/make core/gcc)
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
pkg_description="Jansson is a C library for encoding, decoding and manipulating JSON data."
pkg_upstream_url="http://www.digip.org/jansson/"
