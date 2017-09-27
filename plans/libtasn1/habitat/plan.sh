pkg_origin=mozillareality
pkg_name=libtasn1
pkg_version=4.12

pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_license=('LGPLv2.1+')
pkg_description="Libtasn1 is the ASN.1 library used by GnuTLS, GNU Shishi and some other packages."
pkg_upstream_url=https://www.gnu.org/software/libtasn1/
pkg_source=https://ftp.gnu.org/gnu/${pkg_name}/${pkg_name}-${pkg_version}.tar.gz
pkg_shasum=6753da2e621257f33f5b051cc114d417e5206a0818fe0b1ecfd6153f70934753
pkg_deps=(
  core/glibc
)
pkg_build_deps=(
  core/gcc core/make
)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)
pkg_pconfig_dirs=(lib/pkgconfig)
