pkg_origin=mozillareality
pkg_name=gnutls
pkg_version=3.6.1
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_license=('LGPLv2.1+')
pkg_description="GnuTLS is a secure communications library implementing the SSL, TLS and DTLS "\
"protocols and technologies around them."
pkg_upstream_url=http://www.gnutls.org
pkg_source=https://www.gnupg.org/ftp/gcrypt/${pkg_name}/v3.6/${pkg_name}-${pkg_version}.tar.xz
pkg_shasum=20b10d2c9994bc032824314714d0e84c0f19bdb3d715d8ed55beb7364a8ebaed
pkg_deps=(
  core/glibc
  core/gmp/6.1.0 # core/coreutils conflict
  core/libunistring
  mozillareality/libidn2
  mozillareality/nettle
  mozillareality/libtasn1
  mozillareality/unbound
)
pkg_build_deps=(
  core/gcc
  core/make
  core/pkg-config
  core/diffutils
  core/coreutils
  mozillareality/p11-kit
)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include include/gnutls)
pkg_lib_dirs=(lib)
pkg_pconfig_dirs=(lib/pkgconfig)
