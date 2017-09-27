pkg_name=opus
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="1.2.1"
pkg_license=('BSD')
pkg_source="https://archive.mozilla.org/pub/opus/opus-${pkg_version}.tar.gz"
pkg_filename="${pkg_name}-${pkg_version}.tar.gz"
pkg_shasum="cfafd339ccd9c5ef8d6ab15d7e1a412c054bf4cb4ecbbbcc78c12ef2def70732"
pkg_build_deps=(core/make core/gcc)
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
pkg_description="Opus is a totally open, royalty-free, highly versatile audio codec."
pkg_upstream_url="http://opus-codec.org/"
