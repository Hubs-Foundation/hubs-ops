pkg_name=libgsf
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
pkg_deps=(core/glibc core/perl core/zlib core/libxml2 core/intltool core/gettext mozillareality/expat)

pkg_description="libgsf is a simple i/o library that can read and write common file types and handle structured formats that provide file-system-in-a-file semantics"
pkg_upstream_url="https://github.com/GNOME/libgsf"

do_setup_environment() {
  push_runtime_env PERL5LIB "${pkg_prefix}/lib/perl5/x86_64-linux-thread-multi"
}

do_build() {
  mkdir -p "${pkg_prefix}/cpan"
  source <(perl -I"$(pkg_path_for core/local-lib)/lib/perl5" -Mlocal::lib="$(pkg_path_for core/local-lib)")
  source <(perl -Mlocal::lib="$pkg_prefix/cpan")
  cpan "XML::Parser" --build-args="EXPATLIBPATH=$(pkg_path_for mozillareality/expat)/lib EXPATINCPATH=$(pkg_path_for mozillareality/expat)/include" --local-lib "$pkg_prefix/cpan"
  do_default_build
}

