pkg_name=libconfig
pkg_description="C/C++ library for processing configuration files."
pkg_upstream_url="https://github.com/hyperrealm/libconfig"
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_version="1.7.2"
pkg_source="https://github.com/hyperrealm/libconfig/archive/v1.7.2.tar.gz"
pkg_shasum="f67ac44099916ae260a6c9e290a90809e7d782d96cdd462cac656ebc5b685726"
pkg_license=('LGPL')
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)

pkg_build_deps=(
  core/automake
  core/autoconf
  core/make
  core/gcc
  core/pkg-config
  core/libtool
  core/texinfo
)

do_build() {
  autoreconf
  ./configure --prefix=${pkg_prefix} --disable-examples
  make
}
