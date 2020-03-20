pkg_name=expat
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_version="2.2.9"
pkg_source="https://github.com/libexpat/libexpat/releases/download/R_2_2_9/expat-2.2.9.tar.gz"
pkg_license=('MIT')
pkg_shasum="4456e0aa72ecc7e1d4b3368cd545a5eec7f9de5133a8dc37fdb1efa6174c4947"

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
  core/libjpeg-turbo
  core/libtiff
  mozillareality/expat
)
pkg_deps=(core/glib)

pkg_description="Expat is a stream-oriented XML parser."
pkg_upstream_url="https://github.com/libexpat/libexpat"
