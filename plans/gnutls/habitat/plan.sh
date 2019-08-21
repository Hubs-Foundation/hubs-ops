pkg_origin=mozillareality
pkg_name=gnutls
pkg_version=3.6.9
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_license=('LGPLv2.1+')
pkg_description="GnuTLS is a secure communications library implementing the SSL, TLS and DTLS "\
"protocols and technologies around them."
pkg_upstream_url=http://www.gnutls.org
pkg_source=https://www.gnupg.org/ftp/gcrypt/${pkg_name}/v3.6/${pkg_name}-${pkg_version}.tar.xz
pkg_shasum=4331fca55817ecdd74450b908a6c29b4f05bb24dd13144c6284aa34d872e1fcb
pkg_deps=(
  core/glibc
  core/gmp
  core/libunistring
  core/nettle
  core/libidn2
  core/libtasn1
  mozillareality/unbound/1.9.2
)
pkg_build_deps=(
  core/gcc
  core/make
  core/pkg-config
  core/diffutils
  core/coreutils
  core/p11-kit
)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include include/gnutls)
pkg_lib_dirs=(lib)
pkg_pconfig_dirs=(lib/pkgconfig)
