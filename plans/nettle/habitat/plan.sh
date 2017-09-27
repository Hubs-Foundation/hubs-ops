pkg_origin=mozillareality
pkg_name=nettle
pkg_version=3.3
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_license=('GPL-2.0' 'LGPL3')
pkg_description="Nettle - a low-level cryptographic library"
pkg_upstream_url=https://www.lysator.liu.se/~nisse/nettle/
pkg_source=https://ftp.gnu.org/gnu/${pkg_name}/${pkg_name}-${pkg_version}.tar.gz
pkg_shasum=46942627d5d0ca11720fec18d81fc38f7ef837ea4197c1f630e71ce0d470b11e
pkg_deps=(
  core/glibc
  core/gmp/6.1.0 # core/coreutils conflict
)
pkg_build_deps=(
  core/gcc core/make core/m4
)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include include/nettle)
pkg_lib_dirs=(lib)
pkg_pconfig_dirs=(lib/pkgconfig)

do_build() {
  ./configure \
    --prefix="${pkg_prefix:?}" \
    --with-gmp="$(pkg_path_for core/gmp)"

  make -j "$(nproc)"
}
