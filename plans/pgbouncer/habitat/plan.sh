pkg_name=pgbouncer
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_version="1.12.0"
pkg_license=('ISC')
pkg_source="https://pgbouncer.github.io/downloads/files/${pkg_version}/${pkg_name}-${pkg_version}.tar.gz"
pkg_shasum="1b3c6564376cafa0da98df3520f0e932bb2aebaf9a95ca5b9fa461e9eb7b273e"
pkg_deps=(
  core/glibc
  core/libevent
  core/openssl
  core/c-ares
)
pkg_build_deps=(
  core/autoconf
  core/make
  core/gcc
  core/pkg-config
)
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
pkg_bin_dirs=(bin)
pkg_exports=(
  [port]=pgbouncer.listen_port
)
pkg_exposes=(
  port
)

do_build() {
  ./configure \
    --prefix=$pkg_prefix \
    --with-cares=yes
  make
  return $?
}
