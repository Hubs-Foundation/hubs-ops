pkg_name=libgsf
pkg_description="libgsf is a simple i/o library that can read and write common file types and handle structured formats that provide file-system-in-a-file semantics"
pkg_upstream_url="https://github.com/GNOME/libgsf"
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_version="1.14.41"
pkg_source="http://ftp.acc.umu.se/pub/GNOME/sources/libgsf/1.14/libgsf-1.14.41.tar.xz"
pkg_license=('LGPL')
pkg_shasum="150b98586a1021d5c49b3d4d065d0aa3e3674ae31db131af5372499d2d3f08d3"
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
  core/wget
  core/cpanminus
  core/local-lib
)

pkg_deps=(core/glib core/pcre core/glibc core/perl core/zlib core/libxml2 core/intltool core/gettext core/expat)

do_prepare() {
  do_default_prepare

  env LD_LIBRARY_PATH="$(pkg_path_for core/expat)/lib:${LD_LIBRARY_PATH}" \
    cpanm XML::Parser --configure-args="EXPATLIBPATH=$(pkg_path_for core/expat)/lib export EXPATINCPATH=$(pkg_path_for core/expat)/include"
}

