pkg_name=libvips
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_version="8.8.4"
pkg_source="https://github.com/libvips/libvips/archive/v${pkg_version}.tar.gz"
pkg_license=('LGPL')
pkg_shasum="5c612c4c902327d4378a30c29aa961bd82dbd1fa742dc71e8fb8338ac5e88f78"
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)

pkg_build_deps=(
  core/file
  core/diffutils
  core/make
  core/gcc
  core/pkg-config
  core/automake
  core/autoconf
  core/make
  core/gcc
  core/pkg-config
  core/libtool
)
pkg_deps=(core/glib)

pkg_description="libvips is a demand-driven, horizontally threaded image processing library."
pkg_upstream_url="https://github.com/libvips/libvips"

